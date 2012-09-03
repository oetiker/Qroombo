/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/*
#asset(qx/icon/${qx.icontheme}/22/actions/document-properties.png)
#asset(qx/icon/${qx.icontheme}/22/actions/contact-new.png)
*/

/**
 * The searchView with search box, table and view area
 */
qx.Class.define("qr.ui.AddressTable", {
    extend : qx.ui.core.Widget,
    type : 'singleton',

    construct : function() {
        this.base(arguments);
        this._setLayout(new qx.ui.layout.VBox());
        var tb = new qx.ui.core.Widget().set({ paddingBottom : 8 });
        tb._setLayout(new qx.ui.layout.HBox(5));
        this._add(tb);
        var addBtn = new qx.ui.form.Button(this.tr('Add Address'), 'icon/22/actions/contact-new.png');
        tb._add(addBtn);
        var editBtn = new qx.ui.form.Button(this.tr('Edit Address'), 'icon/22/actions/document-properties.png');
        tb._add(editBtn);
        var model = new qr.data.RemoteTableModel('addresses');

        model.setColumns([ this.tr('AddrId'), this.tr('Name'), this.tr('Street'), this.tr('Zip'), this.tr('Town'), this.tr('Phone'), this.tr('Balance') ],
        [ 'addrid', 'name', 'street', 'zip', 'town', 'phone', 'balance' ]);

        var widths = [ 1, 3, 3, 3, 3, 2 ];

        var control = new qr.ui.Table(model, widths);
        this._add(control);
    }
});