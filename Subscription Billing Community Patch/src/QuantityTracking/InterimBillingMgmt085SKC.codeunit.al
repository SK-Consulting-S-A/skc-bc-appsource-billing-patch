namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

codeunit 70631064 InterimBillingMgmt085SKC
{
    Access = Internal;
    Permissions =
        tabledata SubQuantityHistory085SKC = RIM,
        tabledata "Billing Line" = RIM,
        tabledata "Billing Line Archive" = R,
        tabledata "Subscription Line" = R,
        tabledata "Subscription Header" = R,
        tabledata "Customer Subscription Contract" = R,
        tabledata "Cust. Sub. Contract Line" = R;

    var
        FromDateFilter: Date;
        ToDateFilter: Date;
        NoUnbilledChangesMsg: Label 'No unbilled quantity changes found for contract %1.', Comment = '%1 = Contract No.';
        BillingLinesCreatedMsg: Label '%1 interim billing line(s) created for contract %2. Use "Create Documents" in Recurring Billing to generate the invoice.', Comment = '%1 = Line count, %2 = Contract No.';
        NoBillingArchiveMsg: Label 'Subscription %1 has never been billed. Cannot calculate pro-rata for quantity change on %2.', Comment = '%1 = Subscription No., %2 = Change Date';
        BillingLinesCreatedWithSkipsMsg: Label '%1 interim billing line(s) created for contract %2. %3 change(s) were skipped because no reliable pro-rata rate could be derived. Use "Create Documents" in Recurring Billing to generate the invoice.', Comment = '%1 = Line count, %2 = Contract No., %3 = Skipped count';
        CannotComputeProRataMsg: Label 'Subscription %1: no reliable pro-rata rate could be derived for the quantity change on %2, so no interim billing line was created. Check the Billing Base Period, Billing Rhythm and Price on the subscription line.', Comment = '%1 = Subscription No., %2 = Change Date';
        UnbilledChangesExistErr: Label 'Unbilled quantity changes exist for Subscription %1. Run "Create Interim Billing" on contract %2 before creating the regular billing proposal.', Comment = '%1 = Subscription No., %2 = Contract No.';

    procedure ProcessContract(CustomerContract: Record "Customer Subscription Contract")
    begin
        ProcessContractWithDates(CustomerContract, 0D, 0D);
    end;

    procedure ProcessContractWithDates(CustomerContract: Record "Customer Subscription Contract"; NewFromDate: Date; NewToDate: Date)
    var
        ContractLine: Record "Cust. Sub. Contract Line";
        SubLine: Record "Subscription Line";
        QtyHistory: Record SubQuantityHistory085SKC;
        BillingLine: Record "Billing Line";
        ExpectedCalc: Codeunit SubBillExpectedCalc085SKC;
        BillingFrom: Date;
        BillingTo: Date;
        WindowFrom: Date;
        WindowTo: Date;
        ProRataUnitPrice: Decimal;
        DeltaAmount: Decimal;
        LineCount: Integer;
        SkippedCount: Integer;
    begin
        FromDateFilter := NewFromDate;
        ToDateFilter := NewToDate;

        ContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        ContractLine.SetFilter("Subscription Header No.", '<>%1', '');
        if not ContractLine.FindSet() then begin
            Message(NoUnbilledChangesMsg, CustomerContract."No.");
            exit;
        end;

        repeat
            if not SubLine.Get(ContractLine."Subscription Line Entry No.") then
                SubLine.Init();

            QtyHistory.SetRange(SubscriptionHeaderNo085SKC, ContractLine."Subscription Header No.");
            QtyHistory.SetRange(InterimBilled085SKC, false);
            QtyHistory.SetRange(BillingLineEntryNo085SKC, 0);
            if FromDateFilter <> 0D then
                QtyHistory.SetFilter(ChangeDate085SKC, '>=%1', FromDateFilter);
            if ToDateFilter <> 0D then begin
                if FromDateFilter <> 0D then
                    QtyHistory.SetFilter(ChangeDate085SKC, '>=%1&<=%2', FromDateFilter, ToDateFilter)
                else
                    QtyHistory.SetFilter(ChangeDate085SKC, '<=%1', ToDateFilter);
            end;
            if QtyHistory.FindSet() then
                repeat
                    if QtyHistory.DeltaQuantity085SKC <> 0 then
                        if FindBillingPeriod(SubLine, QtyHistory.ChangeDate085SKC, BillingFrom, BillingTo) then begin
                            WindowFrom := QtyHistory.ChangeDate085SKC;
                            if WindowFrom < BillingFrom then
                                WindowFrom := BillingFrom;
                            WindowTo := BillingTo;

                            // Derive the rate from the shared calculation so the
                            // rhythm-to-base-period ratio is honoured. Reading
                            // "Calculation Base Amount" directly charges a single base
                            // period regardless of how much of the term remains, which
                            // under-bills every line whose rhythm exceeds its base period
                            // (a monthly price billed annually being the common case).
                            if not ExpectedCalc.ProRataUnitPriceForWindow(
                                    SubLine, BillingFrom, BillingTo, WindowFrom, WindowTo, ProRataUnitPrice)
                            then begin
                                Message(CannotComputeProRataMsg,
                                    QtyHistory.SubscriptionHeaderNo085SKC, QtyHistory.ChangeDate085SKC);
                                SkippedCount += 1;
                                continue;
                            end;

                            DeltaAmount := ProRataUnitPrice * QtyHistory.DeltaQuantity085SKC;

                            Clear(BillingLine);
                            BillingLine."User ID" := CopyStr(UserId(), 1, MaxStrLen(BillingLine."User ID"));
                            BillingLine.Partner := BillingLine.Partner::Customer;
                            BillingLine."Partner No." := CustomerContract."Sell-to Customer No.";
                            BillingLine."Subscription Contract No." := CustomerContract."No.";
                            BillingLine."Subscription Contract Line No." := ContractLine."Line No.";
                            BillingLine."Subscription Header No." := SubLine."Subscription Header No.";
                            BillingLine."Subscription Line Entry No." := SubLine."Entry No.";
                            BillingLine."Subscription Line Description" :=
                                CopyStr(
                                    StrSubstNo('Interim: %1 %2->%3',
                                        SubLine.Description,
                                        Format(QtyHistory.OldQuantity085SKC, 0, '<Integer>'),
                                        Format(QtyHistory.NewQuantity085SKC, 0, '<Integer>')),
                                    1, MaxStrLen(BillingLine."Subscription Line Description"));
                            BillingLine."Subscription Line Start Date" := SubLine."Subscription Line Start Date";
                            BillingLine."Subscription Line End Date" := SubLine."Subscription Line End Date";
                            BillingLine."Service Object Quantity" := Abs(QtyHistory.DeltaQuantity085SKC);
                            BillingLine."Billing from" := WindowFrom;
                            BillingLine."Billing to" := WindowTo;
                            BillingLine.Amount := DeltaAmount;
                            BillingLine."Unit Price" := ProRataUnitPrice;
                            BillingLine."Billing Rhythm" := SubLine."Billing Rhythm";
                            BillingLine."Currency Code" := SubLine."Currency Code";
                            BillingLine."Discount %" := SubLine."Discount %";
                            BillingLine.Discount := SubLine.Discount;
                            BillingLine.Insert(true);

                            QtyHistory.BillingLineEntryNo085SKC := BillingLine."Entry No.";
                            QtyHistory.Modify(false);
                            LineCount += 1;
                        end else
                            Message(NoBillingArchiveMsg, QtyHistory.SubscriptionHeaderNo085SKC, QtyHistory.ChangeDate085SKC);
                until QtyHistory.Next() = 0;
        until ContractLine.Next() = 0;

        if LineCount = 0 then
            Message(NoUnbilledChangesMsg, CustomerContract."No.")
        else
            if SkippedCount > 0 then
                Message(BillingLinesCreatedWithSkipsMsg, LineCount, CustomerContract."No.", SkippedCount)
            else
                Message(BillingLinesCreatedMsg, LineCount, CustomerContract."No.");
    end;

    local procedure FindBillingPeriod(SubLine: Record "Subscription Line"; ChangeDate: Date; var BillingFrom: Date; var BillingTo: Date): Boolean
    var
        BillingLineArchive: Record "Billing Line Archive";
    begin
        BillingFrom := 0D;
        BillingTo := 0D;

        // Only an invoice establishes a period that was actually charged. A credit memo
        // reverses a period and must not become the basis for a pro-rata rate. Zero-length
        // periods occur as migration artifacts and would make day weighting meaningless.
        BillingLineArchive.SetRange("Subscription Header No.", SubLine."Subscription Header No.");
        BillingLineArchive.SetRange("Subscription Line Entry No.", SubLine."Entry No.");
        BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
        BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::Invoice);
        BillingLineArchive.SetFilter("Billing from", '<=%1', ChangeDate);
        BillingLineArchive.SetFilter("Billing to", '>=%1', ChangeDate);
        if BillingLineArchive.FindSet() then
            repeat
                if BillingLineArchive."Billing to" > BillingLineArchive."Billing from" then begin
                    BillingFrom := BillingLineArchive."Billing from";
                    BillingTo := BillingLineArchive."Billing to";
                    exit(true);
                end;
            until BillingLineArchive.Next() = 0;

        if SubLine."Next Billing Date" > ChangeDate then begin
            BillingFrom := ChangeDate;
            BillingTo := SubLine."Next Billing Date" - 1;
            exit(true);
        end;

        exit(false);
    end;

    procedure HasUnbilledChangesForContract(ContractNo: Code[20]): Boolean
    var
        ContractLine: Record "Cust. Sub. Contract Line";
        QtyHistory: Record SubQuantityHistory085SKC;
    begin
        ContractLine.SetRange("Subscription Contract No.", ContractNo);
        ContractLine.SetFilter("Subscription Header No.", '<>%1', '');
        if ContractLine.FindSet() then
            repeat
                QtyHistory.SetRange(SubscriptionHeaderNo085SKC, ContractLine."Subscription Header No.");
                QtyHistory.SetRange(InterimBilled085SKC, false);
                QtyHistory.SetRange(BillingLineEntryNo085SKC, 0);
                if not QtyHistory.IsEmpty() then
                    exit(true);
            until ContractLine.Next() = 0;
        exit(false);
    end;

    // --- Event Subscribers ---

    procedure IsInterimBillingEnabled(): Boolean
    var
        Setup: Record "Subscription Contract Setup";
    begin
        exit(Setup.Get() and Setup.EnableInterimBilling085SKC);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Documents", 'OnAfterInsertBillingLineArchiveOnMoveBillingLineToBillingLineArchive', '', false, false)]
    local procedure OnAfterArchiveBillingLine(var BillingLineArchive: Record "Billing Line Archive"; BillingLine: Record "Billing Line")
    var
        QtyHistory: Record SubQuantityHistory085SKC;
    begin
        if not IsInterimBillingEnabled() then
            exit;
        QtyHistory.SetRange(BillingLineEntryNo085SKC, BillingLine."Entry No.");
        QtyHistory.SetRange(InterimBilled085SKC, false);
        if QtyHistory.FindSet(true) then
            repeat
                QtyHistory.InterimBilled085SKC := true;
                QtyHistory.InterimBillingDate085SKC := Today();
                QtyHistory.InterimDocNo085SKC := BillingLineArchive."Document No.";
                QtyHistory.Modify(false);
            until QtyHistory.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Billing Line", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure OnBeforeDeleteBillingLine(var Rec: Record "Billing Line"; RunTrigger: Boolean)
    var
        QtyHistory: Record SubQuantityHistory085SKC;
    begin
        if Rec.IsTemporary() then
            exit;
        if not IsInterimBillingEnabled() then
            exit;
        QtyHistory.SetRange(BillingLineEntryNo085SKC, Rec."Entry No.");
        QtyHistory.SetRange(InterimBilled085SKC, false);
        if QtyHistory.FindSet(true) then
            repeat
                QtyHistory.BillingLineEntryNo085SKC := 0;
                QtyHistory.Modify(false);
            until QtyHistory.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Billing Proposal", 'OnBeforeProcessContractSubscriptionLines', '', false, false)]
    local procedure OnBeforeProcessContractSubLines(var SubscriptionLine: Record "Subscription Line"; BillingDate: Date; BillingToDate: Date; BillingRhythmFilterText: Text; BillingTemplate: Record "Billing Template")
    var
        ContractLine: Record "Cust. Sub. Contract Line";
        QtyHistory: Record SubQuantityHistory085SKC;
        ContractNo: Code[20];
    begin
        if not IsInterimBillingEnabled() then
            exit;

        ContractNo := CopyStr(SubscriptionLine.GetFilter("Subscription Contract No."), 1, MaxStrLen(ContractNo));
        if ContractNo = '' then
            exit;

        ContractLine.SetRange("Subscription Contract No.", ContractNo);
        ContractLine.SetFilter("Subscription Header No.", '<>%1', '');
        if ContractLine.FindSet() then
            repeat
                QtyHistory.SetRange(SubscriptionHeaderNo085SKC, ContractLine."Subscription Header No.");
                QtyHistory.SetRange(InterimBilled085SKC, false);
                QtyHistory.SetRange(BillingLineEntryNo085SKC, 0);
                if not QtyHistory.IsEmpty() then
                    Error(UnbilledChangesExistErr,
                        ContractLine."Subscription Header No.",
                        ContractNo);
            until ContractLine.Next() = 0;
    end;
}
