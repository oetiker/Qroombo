/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/**
  * Booking Navigator
  */
qx.Class.define("qr.ui.Desktop", {
    extend : qx.ui.tabview.TabView,
    type : 'singleton',

    construct : function() {
        this.base(arguments);
        var cfg = this._cfg = qr.data.Config.getInstance();
        this._populate();
        this._tabs.booker.setEnabled(true);
        this._openShop();
        cfg.addListener('changeUserId', this._openShop, this);
    },

    properties : {},
    events : {},

    members : {
        _cfg : null,
        _tabs : null,
        _userInfo : null,
        _reservationTab : null,
        _accountingTab : null,


        /**
         * TODOC
         *
         */
        _openShop : function() {
            var userId = this._cfg.getUserId();
            var enabled = (userId != null);

            [ 'res', 'acct', 'user', 'addr' ].forEach(function(t) {
                this._tabs[t].setEnabled(enabled);
            }, this);
        },


        /**
         * TODOC
         *
         */
        _populate : function() {
            var tabs = this._tabs = {};

            [ {
                k : 'booker',
                l : this.tr('Booker')
            },
            {
                k : 'res',
                l : this.tr('Reservations')
            },
            {
                k : 'acct',
                l : this.tr('Accounting')
            },
            {
                k : 'user',
                l : this.tr('User Data')
            },
            {
                k : 'addr',
                l : this.tr('Invoice Addresses')
            } ].forEach(function(cfg) {
                var page = tabs[cfg.k] = new qx.ui.tabview.Page(cfg.l).set({
                    layout  : new qx.ui.layout.Grow(),
                    enabled : false
                });

                this.add(page);
            },
            this);

            tabs.booker.add(qr.ui.Navigator.getInstance());
            tabs.res.add(qr.ui.ReservationTable.getInstance());
            tabs.acct.add(qr.ui.AccountingTable.getInstance());
            tabs.user.add(qr.ui.ContactTable.getInstance());
            tabs.addr.add(qr.ui.AddressTable.getInstance());
        }
    }
});