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
        var model = new qr.data.RemoteTableModel('reservations');

        model.setColumns([ this.tr('ResId'), this.tr('Date'), this.tr('Time'), this.tr('User'), this.tr('Room'), this.tr('Subject') ],
        [ 'resid', 'date', 'time', 'user', 'room', 'subj' ]);

        var widths = [ 1, 1, 1, 2, 2, 5 ];

        var control = new qr.ui.Table(model, widths);
        this._add(control);
    }
});