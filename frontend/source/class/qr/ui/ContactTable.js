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
qx.Class.define("qr.ui.ContactTable", {
    extend : qx.ui.core.Widget,
    type: 'singleton',
    construct: function(){
        this.base(arguments);
        this._setLayout(new qx.ui.layout.VBox());
        var tb = new qx.ui.core.Widget().set({
            paddingBottom: 8
        });
        tb._setLayout(new qx.ui.layout.HBox(5));
        this._add(tb);
        var addBtn = new qx.ui.form.Button(this.tr('Add Contact'),'icon/22/actions/contact-new.png');
        tb._add(addBtn);   
        var editBtn = new qx.ui.form.Button(this.tr('Edit Contact'),'icon/22/actions/document-properties.png');
        tb._add(editBtn);   
        var model = new qr.data.RemoteTableModel('contact');
        model.setColumns(
            [this.tr('ContactId'),this.tr('First Name'),this.tr('Last Name'),this.tr('eMail'),this.tr('Phone 1'),this.tr('Phone 2')],
            ['contactid','first','last','email','phone1','phone2']
        );
        var widths = [ 1,3,3,3,2,2];
        var control = new qr.ui.Table(model, widths);
        this._add(control);
    }
});
