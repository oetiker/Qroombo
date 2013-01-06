/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/*
#asset(qx/icon/${qx.icontheme}/22/actions/dialog-close.png)
#asset(qx/icon/${qx.icontheme}/22/actions/dialog-cancel.png)
#asset(qx/icon/${qx.icontheme}/22/actions/dialog-ok.png)
*/

/**
  * get details on booking
  */
qx.Class.define("qr.ui.ReservationPopup", {
    extend : qr.ui.EditPopup,
    type : 'singleton',

    construct : function() {
        this.base(arguments, 'resv', this.tr('Reservation Detail'));
        var currencyFormat = new qx.util.format.NumberFormat().set({
            maximumFractionDigits : 2,
            minimumFractionDigits : 2,
            prefix                : qr.data.Config.getInstance().getCurrency() + ' '
        });
        var rpc = qr.data.Server.getInstance();
        this.addListener('changeForm',function(){
            var form = this._form;
            var hold = false;
            var updatePrice = function(e) {
                if (hold) {
                    return;
                }
                hold = true;
                var resvData = form.getData();
                rpc.callAsyncSmart(function(price) {
                    form.setData({ resv_price : currencyFormat.format(price) });
                    hold = false;
                },
                'getPrice', resvData);
            };
            this._form.addListener('changeData', updatePrice, this);
        }, this);
    }
});
