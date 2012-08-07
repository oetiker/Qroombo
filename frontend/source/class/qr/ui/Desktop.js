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
    type: 'singleton',
    construct : function() {
        this.base(arguments);
        this.__populate();        
    },
    properties: {
    },
    events: {
    },
    members : { 
        __tabs: null,
        __reservationTab: null,
        __accountingTab: null,
        __populate: function(){
            var tabs = this.__tabs = {};
            [{ k: 'booker',  l: this.tr('Booker')},
             { k: 'res',     l: this.tr('Reservations')},
             { k: 'acct',    l: this.tr('Accounting')},
             { k: 'contact', l: this.tr('Contact Information')},
             { k: 'addr',    l: this.tr('Invoice Addresses')}
            ].forEach(function(cfg){
                var page = tabs[cfg.k] = new qx.ui.tabview.Page(cfg.l).set({
                    layout: new qx.ui.layout.Grow()
                });
                this.add(page);            
            },this);

            tabs.booker.add(qr.ui.Navigator.getInstance());
            tabs.res.add(qr.ui.ReservationTable.getInstance());
            tabs.acct.add(qr.ui.AccountingTable.getInstance());
            tabs.contact.add(qr.ui.ContactTable.getInstance());
            tabs.addr.add(qr.ui.AddressTable.getInstance());
        }
    }
    
});
