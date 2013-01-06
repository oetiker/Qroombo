/* ************************************************************************
   Copyright: 2009 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/*
#asset(qx/icon/${qx.icontheme}/22/actions/dialog-close.png)
#asset(qx/icon/${qx.icontheme}/22/actions/document-properties.png)
*/

/**
 * The List of Reservations.
 */
qx.Class.define("qr.ui.ReservationTable", {
    extend : qx.ui.core.Widget,
    type : 'singleton',

    construct : function() {
        this.base(arguments);
        this._setLayout(new qx.ui.layout.VBox());
        var tb = new qx.ui.core.Widget().set({ paddingBottom : 8 });
        tb._setLayout(new qx.ui.layout.HBox(5));
        this._add(tb);
        var delBtn = new qx.ui.form.Button(this.tr('Delete'), 'icon/22/actions/dialog-close.png');
        var editBtn = new qx.ui.form.Button(this.tr('Edit'), 'icon/22/actions/document-properties.png');
        tb._add(editBtn);
        tb._add(delBtn);
        var control = new qr.ui.TabView('resv');
        this._add(control);

        var editPop = new qr.ui.EditPopup('resv',this.tr('Reservation Editor'));
        editBtn.addListener('execute',function(){
	    editPop.show(control.getSelectedRecId())
        },this);
    }
});
