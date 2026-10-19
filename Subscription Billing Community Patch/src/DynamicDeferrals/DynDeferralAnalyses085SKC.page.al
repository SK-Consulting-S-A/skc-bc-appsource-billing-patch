namespace SKC.Subscription;

/// <summary>
/// Results of schedule simulations, document rebuilds, and posted deferral
/// audits, newest first.
/// </summary>
page 70631113 DynDeferralAnalyses085SKC
{
    ApplicationArea = All;
    Caption = 'Dynamic Deferral Analysis';
    DeleteAllowed = true;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = DynDeferralAnalysis085SKC;
    SourceTableView = sorting(RunAt085SKC) order(descending);
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(RunAt085SKC; Rec.RunAt085SKC)
                {
                    ToolTip = 'Specifies when the analysis was run.';
                }
                field(AnalysisType085SKC; Rec.AnalysisType085SKC)
                {
                    ToolTip = 'Specifies whether the row came from a schedule simulation, a document rebuild, or a posted deferral audit.';
                }
                field(DocumentNo085SKC; Rec.DocumentNo085SKC)
                {
                    ToolTip = 'Specifies the document the row refers to, where the analysis examined a document.';
                }
                field(DocumentLineNo085SKC; Rec.DocumentLineNo085SKC)
                {
                    ToolTip = 'Specifies the document line the row refers to.';
                }
                field(PostingDate085SKC; Rec.PostingDate085SKC)
                {
                    ToolTip = 'Specifies the posting date of the schedule period.';
                }
                field(PeriodStart085SKC; Rec.PeriodStart085SKC)
                {
                    ToolTip = 'Specifies the first day the period covers.';
                }
                field(PeriodEnd085SKC; Rec.PeriodEnd085SKC)
                {
                    ToolTip = 'Specifies the last day the period covers.';
                }
                field(Days085SKC; Rec.Days085SKC)
                {
                    ToolTip = 'Specifies how many days the period covers, which is what a partial first or last month is prorated on.';
                }
                field(Amount085SKC; Rec.Amount085SKC)
                {
                    ToolTip = 'Specifies the amount recognised in the period.';
                }
                field(CurrencyCode085SKC; Rec.CurrencyCode085SKC)
                {
                    ToolTip = 'Specifies the currency the amount is expressed in.';
                }
                field(Message085SKC; Rec.Message085SKC)
                {
                    StyleExpr = MessageStyle;
                    ToolTip = 'Specifies what the analysis observed.';
                }
                field(IsProblem085SKC; Rec.IsProblem085SKC)
                {
                    ToolTip = 'Specifies whether the row describes a problem rather than an ordinary observation.';
                }
                field(RunId085SKC; Rec.RunId085SKC)
                {
                    ToolTip = 'Specifies the identifier that groups the rows of one analysis run.';
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SimulateSchedule085SKC)
            {
                ApplicationArea = All;
                Caption = 'Simulate Schedule';
                Image = Calculate;
                ToolTip = 'Calculates a dynamic deferral schedule for a billing period and an amount without touching any document.';

                trigger OnAction()
                var
                    Tools: Codeunit DynSubDeferralTools085SKC;
                    SimulationDialog: Page DynDeferralSimulate085SKC;
                    RunId: Guid;
                begin
                    if SimulationDialog.RunModal() <> Action::OK then
                        exit;

                    RunId := Tools.SimulateSchedule(
                        SimulationDialog.GetBillingFrom(), SimulationDialog.GetBillingTo(),
                        SimulationDialog.GetAmount(), SimulationDialog.GetCurrencyCode());
                    Rec.Reset();
                    Rec.SetRange(RunId085SKC, RunId);
                    CurrPage.Update(false);
                end;
            }
            action(ShowProblemsOnly085SKC)
            {
                ApplicationArea = All;
                Caption = 'Show Problems Only';
                Image = FilterLines;
                ToolTip = 'Show only the rows that describe a problem.';

                trigger OnAction()
                begin
                    Rec.SetRange(IsProblem085SKC, true);
                    CurrPage.Update(false);
                end;
            }
            action(ClearFilters085SKC)
            {
                ApplicationArea = All;
                Caption = 'Clear Filters';
                Image = ClearFilter;
                ToolTip = 'Remove the filters applied from this page.';

                trigger OnAction()
                begin
                    Rec.Reset();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(SimulateSchedule085SKC_Promoted; SimulateSchedule085SKC) { }
                actionref(ShowProblemsOnly085SKC_Promoted; ShowProblemsOnly085SKC) { }
                actionref(ClearFilters085SKC_Promoted; ClearFilters085SKC) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        MessageStyle := Rec.IsProblem085SKC ? 'Unfavorable' : 'Standard';
    end;

    var
        MessageStyle: Text;
}
