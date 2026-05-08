namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

codeunit 70631064 InterimBillingMgmt003SKC
{
    Access = Internal;
    Permissions =
        tabledata SubQuantityHistory003SKC = RIM,
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
        UnbilledChangesExistErr: Label 'Unbilled quantity changes exist for Subscription %1. Run "Create Interim Billing" on contract %2 before creating the regular billing proposal.', Comment = '%1 = Subscription No., %2 = Contract No.';

    procedure ProcessContract(CustomerContract: Record "Customer Subscription Contract")
    begin
        ProcessContractWithDates(CustomerContract, 0D, 0D);
    end;

    procedure ProcessContractWithDates(CustomerContract: Record "Customer Subscription Contract"; NewFromDate: Date; NewToDate: Date)
    var
        ContractLine: Record "Cust. Sub. Contract Line";
        SubLine: Record "Subscription Line";
        QtyHistory: Record SubQuantityHistory003SKC;
        BillingLine: Record "Billing Line";
        BillingFrom: Date;
        BillingTo: Date;
        DaysInPeriod: Integer;
        DaysToBill: Integer;
        ProRataUnitPrice: Decimal;
        DeltaAmount: Decimal;
        LineCount: Integer;
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

            QtyHistory.SetRange(SubscriptionHeaderNo003SKC, ContractLine."Subscription Header No.");
            QtyHistory.SetRange(InterimBilled003SKC, false);
            QtyHistory.SetRange(BillingLineEntryNo003SKC, 0);
            if FromDateFilter <> 0D then
                QtyHistory.SetFilter(ChangeDate003SKC, '>=%1', FromDateFilter);
            if ToDateFilter <> 0D then begin
                if FromDateFilter <> 0D then
                    QtyHistory.SetFilter(ChangeDate003SKC, '>=%1&<=%2', FromDateFilter, ToDateFilter)
                else
                    QtyHistory.SetFilter(ChangeDate003SKC, '<=%1', ToDateFilter);
            end;
            if QtyHistory.FindSet() then
                repeat
                    if QtyHistory.DeltaQuantity003SKC <> 0 then
                        if FindBillingPeriod(SubLine, QtyHistory.ChangeDate003SKC, BillingFrom, BillingTo) then begin
                            DaysInPeriod := BillingTo - BillingFrom + 1;
                            if DaysInPeriod <= 0 then
                                DaysInPeriod := 1;
                            DaysToBill := BillingTo - QtyHistory.ChangeDate003SKC + 1;
                            if QtyHistory.ChangeDate003SKC < BillingFrom then
                                DaysToBill := DaysInPeriod;
                            if DaysToBill <= 0 then
                                DaysToBill := 0;

                            ProRataUnitPrice := SubLine."Calculation Base Amount" * DaysToBill / DaysInPeriod;
                            DeltaAmount := ProRataUnitPrice * QtyHistory.DeltaQuantity003SKC;

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
                                        Format(QtyHistory.OldQuantity003SKC, 0, '<Integer>'),
                                        Format(QtyHistory.NewQuantity003SKC, 0, '<Integer>')),
                                    1, MaxStrLen(BillingLine."Subscription Line Description"));
                            BillingLine."Subscription Line Start Date" := SubLine."Subscription Line Start Date";
                            BillingLine."Subscription Line End Date" := SubLine."Subscription Line End Date";
                            BillingLine."Service Object Quantity" := Abs(QtyHistory.DeltaQuantity003SKC);
                            BillingLine."Billing from" := BillingFrom;
                            if QtyHistory.ChangeDate003SKC > BillingFrom then
                                BillingLine."Billing from" := QtyHistory.ChangeDate003SKC;
                            BillingLine."Billing to" := BillingTo;
                            BillingLine.Amount := DeltaAmount;
                            BillingLine."Unit Price" := ProRataUnitPrice;
                            BillingLine."Billing Rhythm" := SubLine."Billing Rhythm";
                            BillingLine."Currency Code" := SubLine."Currency Code";
                            BillingLine."Discount %" := SubLine."Discount %";
                            BillingLine.Discount := SubLine.Discount;
                            BillingLine.Insert(true);

                            QtyHistory.BillingLineEntryNo003SKC := BillingLine."Entry No.";
                            QtyHistory.Modify(false);
                            LineCount += 1;
                        end else
                            Message(NoBillingArchiveMsg, QtyHistory.SubscriptionHeaderNo003SKC, QtyHistory.ChangeDate003SKC);
                until QtyHistory.Next() = 0;
        until ContractLine.Next() = 0;

        if LineCount = 0 then
            Message(NoUnbilledChangesMsg, CustomerContract."No.")
        else
            Message(BillingLinesCreatedMsg, LineCount, CustomerContract."No.");
    end;

    local procedure FindBillingPeriod(SubLine: Record "Subscription Line"; ChangeDate: Date; var BillingFrom: Date; var BillingTo: Date): Boolean
    var
        BillingLineArchive: Record "Billing Line Archive";
    begin
        BillingFrom := 0D;
        BillingTo := 0D;

        BillingLineArchive.SetRange("Subscription Header No.", SubLine."Subscription Header No.");
        BillingLineArchive.SetRange("Subscription Line Entry No.", SubLine."Entry No.");
        BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
        BillingLineArchive.SetFilter("Billing from", '<=%1', ChangeDate);
        BillingLineArchive.SetFilter("Billing to", '>=%1', ChangeDate);
        if BillingLineArchive.FindLast() then begin
            BillingFrom := BillingLineArchive."Billing from";
            BillingTo := BillingLineArchive."Billing to";
            exit(true);
        end;

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
        QtyHistory: Record SubQuantityHistory003SKC;
    begin
        ContractLine.SetRange("Subscription Contract No.", ContractNo);
        ContractLine.SetFilter("Subscription Header No.", '<>%1', '');
        if ContractLine.FindSet() then
            repeat
                QtyHistory.SetRange(SubscriptionHeaderNo003SKC, ContractLine."Subscription Header No.");
                QtyHistory.SetRange(InterimBilled003SKC, false);
                QtyHistory.SetRange(BillingLineEntryNo003SKC, 0);
                if not QtyHistory.IsEmpty() then
                    exit(true);
            until ContractLine.Next() = 0;
        exit(false);
    end;

    // --- Event Subscribers ---

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Documents", 'OnAfterInsertBillingLineArchiveOnMoveBillingLineToBillingLineArchive', '', false, false)]
    local procedure OnAfterArchiveBillingLine(var BillingLineArchive: Record "Billing Line Archive"; BillingLine: Record "Billing Line")
    var
        QtyHistory: Record SubQuantityHistory003SKC;
    begin
        QtyHistory.SetRange(BillingLineEntryNo003SKC, BillingLine."Entry No.");
        QtyHistory.SetRange(InterimBilled003SKC, false);
        if QtyHistory.FindSet(true) then
            repeat
                QtyHistory.InterimBilled003SKC := true;
                QtyHistory.InterimBillingDate003SKC := Today();
                QtyHistory.InterimDocNo003SKC := BillingLineArchive."Document No.";
                QtyHistory.Modify(false);
            until QtyHistory.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Billing Line", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure OnBeforeDeleteBillingLine(var Rec: Record "Billing Line"; RunTrigger: Boolean)
    var
        QtyHistory: Record SubQuantityHistory003SKC;
    begin
        if Rec.IsTemporary() then
            exit;
        QtyHistory.SetRange(BillingLineEntryNo003SKC, Rec."Entry No.");
        QtyHistory.SetRange(InterimBilled003SKC, false);
        if QtyHistory.FindSet(true) then
            repeat
                QtyHistory.BillingLineEntryNo003SKC := 0;
                QtyHistory.Modify(false);
            until QtyHistory.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Billing Proposal", 'OnBeforeProcessContractSubscriptionLines', '', false, false)]
    local procedure OnBeforeProcessContractSubLines(var SubscriptionLine: Record "Subscription Line"; BillingDate: Date; BillingToDate: Date; BillingRhythmFilterText: Text; BillingTemplate: Record "Billing Template")
    var
        ContractLine: Record "Cust. Sub. Contract Line";
        QtyHistory: Record SubQuantityHistory003SKC;
        ContractNo: Code[20];
    begin
        ContractNo := CopyStr(SubscriptionLine.GetFilter("Subscription Contract No."), 1, MaxStrLen(ContractNo));
        if ContractNo = '' then
            exit;

        ContractLine.SetRange("Subscription Contract No.", ContractNo);
        ContractLine.SetFilter("Subscription Header No.", '<>%1', '');
        if ContractLine.FindSet() then
            repeat
                QtyHistory.SetRange(SubscriptionHeaderNo003SKC, ContractLine."Subscription Header No.");
                QtyHistory.SetRange(InterimBilled003SKC, false);
                QtyHistory.SetRange(BillingLineEntryNo003SKC, 0);
                if not QtyHistory.IsEmpty() then
                    Error(UnbilledChangesExistErr,
                        ContractLine."Subscription Header No.",
                        ContractNo);
            until ContractLine.Next() = 0;
    end;
}
