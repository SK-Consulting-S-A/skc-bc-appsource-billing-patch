namespace SKC.Subscription;

enum 70631124 ContractStatus085SKC
{
    Caption = 'Contract Status';
    Extensible = true;

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; Active)
    {
        Caption = 'Active';
    }
    value(2; Expiring)
    {
        Caption = 'Expiring';
    }
    value(3; Ending)
    {
        Caption = 'Ending';
    }
    value(4; Closed)
    {
        Caption = 'Closed';
    }
}
