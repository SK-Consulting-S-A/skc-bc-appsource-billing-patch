// gh-aw v0.89.21 configures Copilot Pi models for Chat Completions. GPT-6 Luna
// and Sol require Responses instead. Use a private copy of the generated Pi
// config: gh-aw mounts the original agent directory read-only in the sandbox.
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const supportedModels = new Set(['gpt-6-luna', 'gpt-6-sol']);

function isInternalGatewayHost(hostname, env) {
    if (hostname === 'api-proxy') return true;
    if (hostname !== 'host.docker.internal' || !env.HOSTALIASES ||
        (env.GH_AW_API_PROXY_HOST_BRIDGE && env.GH_AW_API_PROXY_HOST_BRIDGE !== hostname)) return false;
    try {
        return fs.readFileSync(env.HOSTALIASES, 'utf8').split(/\r?\n/).some(line => {
            const [alias, target] = line.replace(/#.*/, '').trim().split(/\s+/);
            return alias === 'api-proxy' && (target === 'localhost' || target === '127.0.0.1');
        });
    } catch {
        return false;
    }
}

function prepareAgentDirectory(env = process.env) {
    const modelId = env.GH_AW_PI_MODEL_ID;
    const originalDir = env.PI_CODING_AGENT_DIR;
    if (!supportedModels.has(modelId) || env.GH_AW_PI_MODEL !== `copilot/${modelId}` ||
        env.GH_AW_LLM_PROVIDER !== 'github' || !originalDir || !path.isAbsolute(originalDir) ||
        (env.GH_AW_PI_MODELS_JSON_PATH && env.GH_AW_PI_MODELS_JSON_PATH !== path.join(originalDir, 'models.json')) ||
        env.GH_AW_PI_GATEWAY_SECRET_ENV !== 'COPILOT_GITHUB_TOKEN') {
        throw new Error('Unexpected Pi model or gateway configuration; refusing to change its API.');
    }

    const original = JSON.parse(fs.readFileSync(path.join(originalDir, 'models.json'), 'utf8'));
    const gateway = original.providers?.['aw-gateway'];
    if (!gateway || !['openai-completions', 'openai-responses'].includes(gateway.api) ||
        gateway.apiKey !== env.GH_AW_PI_GATEWAY_SECRET_ENV ||
        gateway.models?.length !== 1 || gateway.models[0]?.id !== modelId) {
        throw new Error('Unexpected aw-gateway model definition; refusing to change its API.');
    }
    const endpoint = new URL(gateway.baseUrl);
    if (endpoint.protocol !== 'http:' || !isInternalGatewayHost(endpoint.hostname, env) || !endpoint.port ||
        endpoint.pathname !== '/' || endpoint.search || endpoint.hash) {
        throw new Error('Unexpected aw-gateway endpoint; refusing to route outside the firewall.');
    }

    const temporaryDir = fs.mkdtempSync(path.join(os.tmpdir(), 'gh-aw-pi-responses-'));
    try {
        const agentDir = path.join(temporaryDir, 'agent');
        // Keep staged extensions at their original paths so their module imports
        // resolve exactly as they would without this driver.
        fs.cpSync(originalDir, agentDir, {
            recursive: true,
            filter: source => path.basename(source) !== 'extensions',
        });
        const modelConfig = path.join(agentDir, 'models.json');
        original.providers['aw-gateway'].api = 'openai-responses';
        fs.rmSync(modelConfig);
        fs.writeFileSync(modelConfig, JSON.stringify(original), { mode: 0o600 });
        return { temporaryDir, agentDir, modelId, originalDir };
    } catch (error) {
        fs.rmSync(temporaryDir, { recursive: true, force: true });
        throw error;
    }
}

function piArguments(modelId, runnerTemp, originalDir) {
    if (!supportedModels.has(modelId) || !runnerTemp || !path.isAbsolute(runnerTemp) ||
        !originalDir || !path.isAbsolute(originalDir))
        throw new Error('Missing Pi model or runner action directory.');

    const actionsDir = path.join(runnerTemp, 'gh-aw', 'actions');
    const extensions = ['pi_provider.cjs', 'pi_steering_extension.cjs'].map(name => path.join(actionsDir, name));
    if (extensions.some(extension => !fs.existsSync(extension)))
        throw new Error('Required gh-aw Pi extension is missing.');
    if (modelId === 'gpt-6-luna') {
        // Custom workflow steps stage files under RUNNER_TEMP, not the /tmp
        // directory used by the generated models.json.
        const solReview = path.join(runnerTemp, 'gh-aw', 'pi-agent-dir', 'extensions', 'sol-review.js');
        if (!fs.existsSync(solReview)) throw new Error('Staged Sol review extension is missing.');
        extensions.push(solReview);
    }

    return ['--print', '--mode', 'json', '--no-session', '--model', `aw-gateway/${modelId}`,
        ...extensions.flatMap(extension => ['--extension', extension])];
}

async function runDriver(env = process.env, spawnPi = spawn) {
    const { temporaryDir, agentDir, modelId, originalDir } = prepareAgentDirectory(env);
    try {
        const args = piArguments(modelId, env.RUNNER_TEMP, originalDir);
        const prompt = env.GH_AW_PROMPT;
        if (!prompt || !fs.existsSync(prompt)) throw new Error('gh-aw Pi prompt is missing.');

        const child = spawnPi('pi', args, {
            env: { ...env, PI_CODING_AGENT_DIR: agentDir },
            stdio: ['pipe', 'inherit', 'inherit'],
        });
        const forwardSignal = () => child.kill('SIGTERM');
        process.on('SIGTERM', forwardSignal);
        process.on('SIGINT', forwardSignal);
        try {
            const completed = new Promise((resolve, reject) => {
                child.once('error', reject);
                child.once('close', (code, signal) => resolve(signal ? 1 : code ?? 1));
            });
            const input = fs.createReadStream(prompt);
            let streamFailed = false;
            const failStream = error => {
                if (error.code === 'EPIPE') return;
                streamFailed = true;
                console.error(`Pi prompt stream failed: ${error.message}`);
                child.kill('SIGTERM');
            };
            input.on('error', error => {
                child.stdin.end();
                failStream(error);
            });
            child.stdin.on('error', failStream);
            input.pipe(child.stdin);
            const code = await completed;
            input.destroy();
            return streamFailed ? 1 : code;
        } finally {
            process.off('SIGTERM', forwardSignal);
            process.off('SIGINT', forwardSignal);
        }
    } finally {
        fs.rmSync(temporaryDir, { recursive: true, force: true });
    }
}

if (require.main === module) {
    runDriver().then(code => { process.exitCode = code; }).catch(error => {
        console.error(`Pi Responses driver failed: ${error.message}`);
        process.exitCode = 1;
    });
}

module.exports = { prepareAgentDirectory, piArguments, runDriver };