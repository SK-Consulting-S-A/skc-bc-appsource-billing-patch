namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

codeunit 70631060 ContractMerge003SKC
{
    Access = Internal;
    TableNo = "Customer Subscription Contract";

    var
        MergeLog: TextBuilder;
        DryRun: Boolean;
        ContractsMerged: Integer;
        LinesMoved: Integer;
        Errors: Integer;

    procedure SetDryRun(NewDryRun: Boolean)
    begin
        DryRun := NewDryRun;
    end;

    procedure GetLog(): Text
    begin
        exit(MergeLog.ToText());
    end;

    procedure GetStats(var OutMerged: Integer; var OutLinesMoved: Integer; var OutErrors: Integer)
    begin
        OutMerged := ContractsMerged;
        OutLinesMoved := LinesMoved;
        OutErrors := Errors;
    end;

    procedure MergeAllByCustomer()
    var
        Contract: Record "Customer Subscription Contract";
        CustomerList: List of [Code[20]];
        CustomerNo: Code[20];
    begin
        ContractsMerged := 0;
        LinesMoved := 0;
        Errors := 0;

        Log('=== Contract Merge: 1 per Customer ===');
        if DryRun then
            Log('MODE: DRY RUN (no changes)')
        else
            Log('MODE: EXECUTE');

        Contract.SetCurrentKey("Sell-to Customer No.");
        if Contract.FindSet() then
            repeat
                if not CustomerList.Contains(Contract."Sell-to Customer No.") then
                    CustomerList.Add(Contract."Sell-to Customer No.");
            until Contract.Next() = 0;

        Log(StrSubstNo('Customers with contracts: %1', CustomerList.Count()));

        foreach CustomerNo in CustomerList do
            MergeContractsForCustomer(CustomerNo);

        Log('');
        Log('=== SUMMARY ===');
        Log(StrSubstNo('Contracts merged (emptied & deleted): %1', ContractsMerged));
        Log(StrSubstNo('Lines moved to target contracts: %1', LinesMoved));
        Log(StrSubstNo('Errors: %1', Errors));
    end;

    local procedure MergeContractsForCustomer(CustomerNo: Code[20])
    var
        Contract: Record "Customer Subscription Contract";
        TargetContractNo: Code[20];
        ContractCount: Integer;
    begin
        Contract.SetRange("Sell-to Customer No.", CustomerNo);
        ContractCount := Contract.Count();
        if ContractCount <= 1 then
            exit;

        Contract.FindFirst();
        TargetContractNo := Contract."No.";

        Log('');
        Log(StrSubstNo('Customer %1: %2 contracts -> merging into %3',
            CustomerNo, ContractCount, TargetContractNo));

        Contract.FindSet();
        repeat
            if Contract."No." <> TargetContractNo then
                MoveContractLines(Contract."No.", TargetContractNo, CustomerNo);
        until Contract.Next() = 0;
    end;

    local procedure MoveContractLines(SourceContractNo: Code[20]; TargetContractNo: Code[20]; CustomerNo: Code[20])
    var
        SourceLine: Record "Cust. Sub. Contract Line";
        SourceContract: Record "Customer Subscription Contract";
        NewLineNo: Integer;
        SourceLineCount: Integer;
    begin
        SourceLine.SetRange("Subscription Contract No.", SourceContractNo);
        SourceLineCount := SourceLine.Count();

        if SourceLineCount = 0 then begin
            Log(StrSubstNo('  %1: no lines, deleting empty contract', SourceContractNo));
            if not DryRun then
                if SourceContract.Get(SourceContractNo) then
                    if SourceContract.Delete(false) then
                        ContractsMerged += 1
                    else begin
                        Log(StrSubstNo('    ERROR deleting contract %1', SourceContractNo));
                        Errors += 1;
                    end;
            exit;
        end;

        Log(StrSubstNo('  %1 -> %2: moving %3 lines',
            SourceContractNo, TargetContractNo, SourceLineCount));

        NewLineNo := GetNextLineNo(TargetContractNo);

        SourceLine.FindSet();
        repeat
            MoveSingleLine(SourceLine, TargetContractNo, NewLineNo);
            NewLineNo += 10000;
        until SourceLine.Next() = 0;

        if not DryRun then begin
            if SourceContract.Get(SourceContractNo) then
                if SourceContract.Delete(false) then begin
                    ContractsMerged += 1;
                    Log(StrSubstNo('    Deleted source contract %1', SourceContractNo));
                end else begin
                    Log(StrSubstNo('    ERROR deleting source contract %1', SourceContractNo));
                    Errors += 1;
                end;
        end else
            Log(StrSubstNo('    [DRY] Would delete source contract %1', SourceContractNo));
    end;

    local procedure MoveSingleLine(var SourceLine: Record "Cust. Sub. Contract Line"; TargetContractNo: Code[20]; NewLineNo: Integer)
    var
        NewLine: Record "Cust. Sub. Contract Line";
        SubLine: Record "Subscription Line";
        SubEntryNo: Integer;
        Description: Text;
    begin
        SubEntryNo := SourceLine."Subscription Line Entry No.";
        Description := SourceLine."Subscription Line Description";

        if DryRun then begin
            Log(StrSubstNo('    [DRY] Would move line %1-%2 (Entry %3: %4) -> %5-%6',
                SourceLine."Subscription Contract No.", SourceLine."Line No.",
                SubEntryNo, Description,
                TargetContractNo, NewLineNo));
            LinesMoved += 1;
            exit;
        end;

        NewLine.TransferFields(SourceLine);
        NewLine."Subscription Contract No." := TargetContractNo;
        NewLine."Line No." := NewLineNo;
        if not NewLine.Insert(false) then begin
            Log(StrSubstNo('    ERROR inserting line %1-%2 for entry %3',
                TargetContractNo, NewLineNo, SubEntryNo));
            Errors += 1;
            exit;
        end;

        if SubEntryNo <> 0 then begin
            SubLine.SetRange("Entry No.", SubEntryNo);
            if SubLine.FindFirst() then begin
                SubLine."Subscription Contract No." := TargetContractNo;
                SubLine."Subscription Contract Line No." := NewLineNo;
                if not SubLine.Modify(false) then begin
                    Log(StrSubstNo('    ERROR updating sub line entry %1', SubEntryNo));
                    Errors += 1;
                    NewLine.Delete(false);
                    exit;
                end;
            end;
        end;

        SourceLine.Delete(false);
        LinesMoved += 1;

        Log(StrSubstNo('    Moved: %1-%2 -> %3-%4 (Entry %5: %6)',
            SourceLine."Subscription Contract No.", SourceLine."Line No.",
            TargetContractNo, NewLineNo,
            SubEntryNo, Description));
    end;

    local procedure GetNextLineNo(ContractNo: Code[20]): Integer
    var
        ContractLine: Record "Cust. Sub. Contract Line";
    begin
        ContractLine.SetRange("Subscription Contract No.", ContractNo);
        if ContractLine.FindLast() then
            exit(ContractLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure Log(Msg: Text)
    begin
        MergeLog.AppendLine(Msg);
    end;
}
