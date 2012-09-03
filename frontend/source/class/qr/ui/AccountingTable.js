/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/*
#asset(qx/icon/${qx.icontheme}/22/actions/document-print.png)
#asset(qx/icon/${qx.icontheme}/22/apps/utilities-calculator.png)
*/

/**
 * The searchView with search box, table and view area
 */
qx.Class.define("qr.ui.AccountingTable", {
    extend : qx.ui.core.Widget,
    type : 'singleton',

    construct : function() {
        this.base(arguments);
        this._setLayout(new qx.ui.layout.VBox());
        var tb = new qx.ui.core.Widget().set({ paddingBottom : 8 });
        tb._setLayout(new qx.ui.layout.HBox(5));
        this._add(tb);
        var printBtn = new qx.ui.form.Button(this.tr('Print Invoice'), 'icon/22/actions/document-print.png');
        tb._add(printBtn);
        var payBtn = new qx.ui.form.Button(this.tr('Add Payment'), 'icon/22/apps/utilities-calculator.png');
        tb._add(payBtn);
        tb._add(new qx.ui.core.Spacer(1), { flex : 1 });
        var balance = new qx.ui.basic.Atom(this.tr('Balance: %1 CHF', 0)).set({ center : true }).set({ font : 'headline' });
        tb._add(balance);
        var model = new qr.data.RemoteTableModel('accounting');

        model.setColumns([ this.tr('AcctId'), this.tr('Date'), this.tr('Remark'), this.tr('User'), this.tr('ResId'), this.tr('Amount') ],
        [ 'acctid', 'date', 'rem', 'user', 'resid', 'amount' ]);

        var widths = [ 1, 2, 5, 2, 2, 2 ];

        var control = new qr.ui.Table(model, widths);
        this._add(control);
    }
});