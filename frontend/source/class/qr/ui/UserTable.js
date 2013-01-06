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
qx.Class.define("qr.ui.UserTable", {
    extend : qx.ui.core.Widget,
    type : 'singleton',

    construct : function() {
        this.base(arguments);
        this._setLayout(new qx.ui.layout.VBox());
        var tb = new qx.ui.core.Widget().set({ paddingBottom : 8 });
        tb._setLayout(new qx.ui.layout.HBox(5));
        this._add(tb);
        var control = new qr.ui.TabView('user');
        this._add(control);

//      var addBtn = new qx.ui.form.Button(this.tr('Add User'), 'icon/22/actions/contact-new.png');
//      tb._add(addBtn);

        var editBtn = new qx.ui.form.Button(this.tr('Edit User'), 'icon/22/actions/document-properties.png');
        tb._add(editBtn);
        var editPopup = new qr.ui.EditPopup('user',this.tr("User Editor"));
        editBtn.addListener('execute',function(){ editPopup.show(control.getSelectedRecId()) }, this );
        editPopup.addListener('close',function(){ control.reloadData() }, this);

    }
});
