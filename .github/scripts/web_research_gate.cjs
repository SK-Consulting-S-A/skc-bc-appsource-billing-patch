'use strict';

const dns = require('node:dns');
const net = require('node:net');

const maximumBodyLength = 60_000;
const maximumUrlLength = 2_048;
const maximumDestinationCount = 6;
const researchLabel = 'web-research';
const trustedPermissions = new Set(['admin', 'maintain', 'write']);

const blockedAddresses = new net.BlockList();
for (const [address, prefix] of [
    ['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10],
    ['127.0.0.0', 8], ['169.254.0.0', 16], ['172.16.0.0', 12],
    ['192.0.0.0', 24], ['192.0.2.0', 24], ['192.88.99.0', 24],
    ['192.168.0.0', 16], ['198.18.0.0', 15], ['198.51.100.0', 24],
    ['203.0.113.0', 24], ['224.0.0.0', 4], ['240.0.0.0', 4],
]) {
    blockedAddresses.addSubnet(address, prefix, 'ipv4');
}
for (const [address, prefix] of [
    // Conservatively exclude special-purpose space, Teredo, 6to4, and documentation.
    ['2001::', 23], ['2001:db8::', 32], ['2002::', 16],
    ['3ffe::', 16], ['3fff::', 20],
]) {
    blockedAddresses.addSubnet(address, prefix, 'ipv6');
}
const globalIpv6Addresses = new net.BlockList();
globalIpv6Addresses.addSubnet('2000::', 3, 'ipv6');

/** Classify numeric DNS answers, never allowing mapped or other non-global IPv6. */
function isPublicAddress(address) {
    if (typeof address !== 'string' || address.includes('%')) return false;
    const family = net.isIP(address);
    if (family === 4) return !blockedAddresses.check(address, 'ipv4');
    if (family !== 6) return false;
    // ISATAP embeds IPv4 behind a 5efe interface identifier; deny conservatively.
    if (/(?:^|:)5efe:/i.test(address)) return false;
    return globalIpv6Addresses.check(address, 'ipv6') &&
        !blockedAddresses.check(address, 'ipv6');
}

function trimMarkdownSuffix(candidate) {
    let result = candidate;
    let unmatchedClosings = (result.match(/\)/g) || []).length -
        (result.match(/\(/g) || []).length;
    while (result.length > 0) {
        if (/[,.]$/.test(result)) {
            result = result.slice(0, -1);
        } else if (result.endsWith(')') && unmatchedClosings > 0) {
            result = result.slice(0, -1);
            unmatchedClosings -= 1;
        } else {
            break;
        }
    }
    return result;
}

/** Validate before WHATWG normalization can erase an explicit port or backslash. */
function canonicalizeResearchUrl(candidate) {
    if (typeof candidate !== 'string' || candidate.length > maximumUrlLength) {
        throw new Error('Invalid research URL length.');
    }
    if (!/^https:\/\//i.test(candidate) || /[\s\\?#]/.test(candidate)) {
        throw new Error('Research URLs must be credential-free HTTPS URLs.');
    }
    const authority = candidate.slice(8).split('/')[0];
    if (!authority || /[@*\[\]]/.test(authority)) {
        throw new Error('Invalid research authority.');
    }
    const portIndex = authority.indexOf(':');
    if (portIndex !== -1 && authority.slice(portIndex) !== ':443') {
        throw new Error('Only the HTTPS default port is allowed.');
    }
    const parsedUrl = new URL(candidate);
    if (parsedUrl.protocol !== 'https:' || parsedUrl.username || parsedUrl.password ||
        parsedUrl.search || parsedUrl.hash || parsedUrl.port) {
        throw new Error('Invalid research URL components.');
    }
    const hostname = parsedUrl.hostname.replace(/\.$/, '').toLowerCase();
    const labels = hostname.split('.');
    if (net.isIP(hostname) || hostname.length > 253 || labels.length < 2 ||
        labels.some(label => !/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(label)) ||
        /(?:^|\.)(?:localhost|local|internal|test|invalid|example)$/.test(hostname)) {
        throw new Error('Research requires a public DNS hostname.');
    }
    parsedUrl.hostname = hostname;
    const canonicalUrl = parsedUrl.href;
    if (canonicalUrl.length > maximumUrlLength) {
        throw new Error('Invalid canonical research URL length.');
    }
    return canonicalUrl;
}

/** GitHub references stay internal; every external HTTPS candidate is validated. */
function extractResearchUrls(body) {
    if (typeof body !== 'string' || body.length > maximumBodyLength) {
        throw new Error('Invalid research body length.');
    }
    const urls = new Set();
    for (const match of body.matchAll(/\bhttps:[^\s<>"'`]+/gi)) {
        const candidate = trimMarkdownSuffix(match[0]);
        // Enriched issues contain repository links and GitHub search queries.
        // Never send those private identifiers to external research or count
        // them against the documentation limit. Match exact HTTPS authorities,
        // not lookalike hosts, credentials, or unsafe ports.
        if (/^https:\/\/(?:www\.)?github\.com(?::443)?(?:[/?#]|$)/i.test(candidate)) continue;
        urls.add(canonicalizeResearchUrl(candidate));
        if (urls.size > maximumDestinationCount) {
            throw new Error('Too many research destinations.');
        }
    }
    if (urls.size === 0) throw new Error('No HTTPS research destinations.');
    return [...urls];
}

/**
 * Deterministic github-script approval gate. No issue text or caught errors are
 * logged. The caller must enforce the returned allowlist at fetch time as well:
 * DNS rebinding, redirects, and whether a path is public cannot be proven here.
 */
async function approveResearch({ github, context, core, resolveHostname = hostname =>
    dns.promises.lookup(hostname, { all: true, verbatim: true }) }) {
    const deny = reason => {
        core.setOutput('approved', false);
        core.info(`Web research denied: ${reason}`);
        return null;
    };
    const payload = context?.payload;
    const originalIssue = payload?.issue;
    const sender = payload?.sender;
    if (context?.eventName !== 'issues' || payload?.action !== 'labeled' ||
        payload?.label?.name !== researchLabel || !originalIssue ||
        originalIssue.pull_request || sender?.type !== 'User' ||
        typeof sender.login !== 'string' || !sender.login ||
        !Number.isSafeInteger(originalIssue.number) || originalIssue.number <= 0) {
        return deny('ineligible trigger.');
    }
    const issueNumber = originalIssue.number;
    const originalBody = originalIssue.body;
    if (typeof originalBody !== 'string' || originalBody.length > maximumBodyLength) {
        return deny('invalid body length.');
    }
    const owner = context.repo?.owner;
    const repo = context.repo?.repo;
    if (typeof owner !== 'string' || !owner || typeof repo !== 'string' || !repo) {
        return deny('missing repository context.');
    }

    let urls;
    let hosts;
    try {
        const permissionResponse = await github.rest.repos.getCollaboratorPermissionLevel({
            owner, repo, username: sender.login,
        });
        if (!trustedPermissions.has(permissionResponse?.data?.permission)) {
            return deny('sender lacks a trusted collaborator permission.');
        }
        const issueResponse = await github.rest.issues.get({ owner, repo, issue_number: issueNumber });
        const currentIssue = issueResponse?.data;
        if (currentIssue?.state !== 'open' || currentIssue.pull_request ||
            currentIssue.body !== originalBody || !Array.isArray(currentIssue.labels) ||
            !currentIssue.labels.some(label => label?.name === researchLabel)) {
            return deny('issue state, label, or body changed.');
        }

        urls = extractResearchUrls(originalBody);
        hosts = [...new Set(urls.map(url => new URL(url).hostname))];
        if (hosts.length > maximumDestinationCount) return deny('too many research hosts.');
        // The unique host list is the invocation-local DNS cache: one lookup per host.
        for (const hostname of hosts) {
            const answers = await resolveHostname(hostname);
            if (!Array.isArray(answers) || answers.length === 0 || answers.some(answer =>
                !answer || ![4, 6].includes(answer.family) ||
                net.isIP(answer.address) !== answer.family || !isPublicAddress(answer.address))) {
                return deny('unsafe or missing DNS answers.');
            }
        }
    } catch {
        return deny('permission, issue, destination, or DNS validation failed.');
    }

    // Construct exclusively from validated destinations, never title/body prose or context.repo.
    const query = `Public documentation research: ${urls.map(url => {
        const destination = new URL(url);
        return `${destination.hostname} ${destination.pathname.replace(/[^a-z0-9/_-]/gi, ' ')}`.trim();
    }).join('; ')}`;
    const result = { issueNumber, urls: JSON.stringify(urls), hosts: hosts.join(','), query };
    core.setOutput('approved', true);
    core.setOutput('issue_number', result.issueNumber);
    core.setOutput('research_urls', result.urls);
    core.setOutput('research_hosts', result.hosts);
    core.setOutput('research_query', result.query);
    core.info('Web research approved for validated public HTTPS destinations.');
    return result;
}

/** Accept environment digits or a numeric ID, without coercing ambiguous input. */
function canonicalPositiveId(value) {
    if (typeof value === 'string' && (!/^[1-9]\d*$/.test(value) ||
        String(Number(value)) !== value)) return null;
    if (typeof value !== 'string' && typeof value !== 'number') return null;
    const number = Number(value);
    return Number.isSafeInteger(number) && number > 0 ? number : null;
}

/** An explicit issue marker must be the entire first line, without duplicates. */
function hasValidResearchMarker(body, prefix) {
    const markers = body.match(/skc-web-research/gi) || [];
    return markers.length === 0 ||
        (markers.length === 1 && body.split(/\r?\n/, 1)[0] === prefix);
}

/** Both generated metadata fields must belong to one unambiguous complete footer. */
function hasResearchRunFooter(body, runId) {
    if ((body.match(/<!--\s*gh-aw-agentic-workflow\b/gi) || []).length !== 1) return false;
    for (const match of body.matchAll(/<!-- gh-aw-agentic-workflow:((?:(?!-->|<!--)[\s\S])*)-->/g)) {
        const footer = match[1];
        const workflows = [...footer.matchAll(/(?:^|[,\r\n])\s*workflow_id:\s*([^,\r\n]+)\s*(?=,|$)/g)];
        const ids = [...footer.matchAll(/(?:^|[,\r\n])\s*id:\s*([^,\r\n]+)(?=,)/g)];
        if (workflows.length === 1 && ids.length === 1 &&
            workflows[0][1].trim() === 'al-issue-web-research-agent' &&
            ids[0][1].trim() === String(runId)) return true;
    }
    return false;
}

/** Fail-closed deterministic handoff; never mutate labels or log API error text. */
async function handoffResearch({ github, context, core, issueNumber }) {
    const deny = reason => {
        core.warning(`Web research handoff denied: ${reason}`);
        return null;
    };
    const target = canonicalPositiveId(issueNumber);
    const runId = canonicalPositiveId(context?.runId);
    const payload = context?.payload;
    const originalIssue = payload?.issue;
    const sender = payload?.sender;
    const owner = context?.repo?.owner;
    const repo = context?.repo?.repo;
    const defaultBranch = payload?.repository?.default_branch;
    const originalBody = originalIssue?.body;
    if (!target || !runId || context?.eventName !== 'issues' ||
        payload?.action !== 'labeled' || payload?.label?.name !== researchLabel ||
        originalIssue?.number !== target || originalIssue?.pull_request ||
        typeof originalBody !== 'string' || sender?.type !== 'User' ||
        typeof sender.login !== 'string' || !sender.login ||
        typeof owner !== 'string' || !owner || typeof repo !== 'string' || !repo ||
        typeof defaultBranch !== 'string' || !defaultBranch) {
        return deny('ineligible trigger or identifier.');
    }

    try {
        const permission = await github.rest.repos.getCollaboratorPermissionLevel({
            owner, repo, username: sender.login,
        });
        if (!trustedPermissions.has(permission?.data?.permission)) {
            return deny('original approver is no longer authorized.');
        }
        const { data: currentIssue } = await github.rest.issues.get({
            owner, repo, issue_number: target,
        });
        if (currentIssue?.number !== target || currentIssue.state !== 'open' ||
            currentIssue.pull_request || currentIssue.body !== originalBody ||
            !Array.isArray(currentIssue.labels) ||
            !currentIssue.labels.some(label => label?.name === researchLabel)) {
            return deny('issue state, label, or body changed.');
        }
        const { data: run } = await github.rest.actions.getWorkflowRun({
            owner, repo, run_id: context.runId,
        });
        const now = Date.now();
        const runCreated = Date.parse(run?.created_at);
        if (run?.id !== runId || run?.head_repository?.full_name !== `${owner}/${repo}` ||
            run.head_branch !== defaultBranch || run.event !== 'issues' ||
            typeof run.path !== 'string' || /\s/.test(run.path) ||
            !/^\.github\/workflows\/al-issue-web-research\.yml(?:@[^\s]+)?$/.test(run.path) ||
            typeof run.head_sha !== 'string' || run.head_sha.length !== 40 ||
            !/^[a-f0-9]{40}$/i.test(run.head_sha) ||
            !Number.isFinite(runCreated) || runCreated > now) {
            return deny('untrusted wrapper run.');
        }
        const { data: comments } = await github.rest.issues.listComments({
            owner, repo, issue_number: target, per_page: 100,
        });
        if (!Array.isArray(comments)) return deny('invalid comment response.');
        const prefix = `<!-- skc-web-research: issue=${target} -->`;
        const candidates = comments.slice(0, 100).filter(comment => {
            const created = Date.parse(comment?.created_at);
            return Number.isSafeInteger(comment?.id) && comment.id > 0 &&
                typeof comment?.body === 'string' && hasValidResearchMarker(comment.body, prefix) &&
                hasResearchRunFooter(comment.body, runId) &&
                Number.isFinite(created) && created >= runCreated && created <= now;
        }).sort((left, right) => Date.parse(right.created_at) - Date.parse(left.created_at) ||
            right.id - left.id);
        for (const report of candidates) {
            const author = report.user;
            if (typeof author?.login !== 'string' || !author.login) continue;
            if (!(author.login === 'github-actions[bot]' && author.type === 'Bot')) {
                if (author.type !== 'User') continue;
                const writerPermission = await github.rest.repos.getCollaboratorPermissionLevel({
                    owner, repo, username: author.login,
                });
                if (!trustedPermissions.has(writerPermission?.data?.permission)) continue;
            }
            // workflow_dispatch requires a branch/tag, not a commit SHA. Reject
            // a moved branch rather than dispatching against unreviewed changes.
            const { data: branch } = await github.rest.repos.getBranch({
                owner, repo, branch: defaultBranch,
            });
            if (branch?.name !== defaultBranch || branch?.commit?.sha !== run.head_sha) {
                return deny('default branch changed after research started.');
            }
            await github.rest.actions.createWorkflowDispatch({
                owner, repo, workflow_id: 'al-issue-triage.lock.yml', ref: defaultBranch,
                inputs: {
                    issue_number: String(target), issue_action: 'clarification-received',
                    comment_id: String(report.id)
                },
            });
            return { issueNumber: target, commentId: report.id, runId };
        }
        return deny('no eligible research report found.');
    } catch (error) {
        const status = Number.isInteger(error?.status) && error.status >= 400 && error.status <= 599 ?
            ` (HTTP ${error.status})` : '';
        return deny(`GitHub API or validation failed${status}.`);
    }
}

module.exports = {
    approveResearch, canonicalizeResearchUrl, extractResearchUrls, isPublicAddress,
    handoffResearch
};