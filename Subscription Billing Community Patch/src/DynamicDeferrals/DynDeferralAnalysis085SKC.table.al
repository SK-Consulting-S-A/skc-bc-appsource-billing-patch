namespace SKC.Subscription;

/// <summary>
/// Output of a schedule simulation, a document rebuild, or a posted deferral
/// audit.
///
/// The same table is used as the temporary buffer inside the schedule
/// calculation, so what a simulation shows is literally what the posting path
/// would build rather than a second implementation that could drift from it.
/// </summary>
table 70631110 DynDeferralAnalysis085SKC
{
    Caption = 'Dynamic Deferral Analysis';
    DataClassification = SystemMetadata;
    DrillDownPageId = DynDeferralAnalyses085SKC;
    LookupPageId = DynDeferralAnalyses085SKC;

    fields
    {
        field(1; RunId085SKC; Guid)
        {
            Caption = 'Run ID';
            DataClassification = SystemMetadata;
        }
        field(2; LineNo085SKC; Integer)
        {
            Caption = 'Line No.';
            DataClassification = SystemMetadata;
        }
        field(3; AnalysisType085SKC; Enum DynDeferralAnalysisType085SKC)
        {
            Caption = 'Analysis Type';
            DataClassification = SystemMetadata;
        }
        field(4; RunAt085SKC; DateTime)
        {
            Caption = 'Run At';
            DataClassification = SystemMetadata;
        }
        field(5; DocumentNo085SKC; Code[20])
        {
            Caption = 'Document No.';
            DataClassification = CustomerContent;
        }
        field(6; DocumentLineNo085SKC; Integer)
        {
            Caption = 'Document Line No.';
            DataClassification = CustomerContent;
        }
        field(7; PostingDate085SKC; Date)
        {
            Caption = 'Posting Date';
            DataClassification = CustomerContent;
        }
        field(8; PeriodStart085SKC; Date)
        {
            Caption = 'Period Start';
            DataClassification = CustomerContent;
        }
        field(9; PeriodEnd085SKC; Date)
        {
            Caption = 'Period End';
            DataClassification = CustomerContent;
        }
        field(10; Days085SKC; Integer)
        {
            Caption = 'Days';
            DataClassification = CustomerContent;
        }
        field(11; Amount085SKC; Decimal)
        {
            Caption = 'Amount';
            AutoFormatType = 1;
            DataClassification = CustomerContent;
        }
        field(12; CurrencyCode085SKC; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
        }
        field(13; Message085SKC; Text[250])
        {
            Caption = 'Message';
            DataClassification = SystemMetadata;
        }
        field(14; IsProblem085SKC; Boolean)
        {
            Caption = 'Problem';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; RunId085SKC, LineNo085SKC)
        {
            Clustered = true;
        }
        key(Recent; RunAt085SKC)
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; PostingDate085SKC, Days085SKC, Amount085SKC)
        {
        }
    }
}
