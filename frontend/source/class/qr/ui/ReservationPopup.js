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
    extend : qx.ui.window.Window,
    type: 'singleton',
    construct : function() {                
        this.base(arguments,this.tr('Reservation Detail'));
        this.set({
            allowClose: true,
            allowMaximize: false,
            allowMinimize: false,
            showClose: true,
            showMaximize: false,
            showMinimize: false,
            showStatusbar: false,
            width: 400,
            layout: new qx.ui.layout.VBox(15),
            modal: true
        });
        var cfg = this._cfg = qr.data.Config.getInstance();
        cfg.addListener('addrChanged',this._updateForm,this);
        this.addListener('appear',function(){this.center()},this);
        // ok now we open for real as we are now authenticated
        this._populateForm();
    },
    properties: {
        reservation: {
            event: 'reservationChanged',
            init: null
        }
    },
    events: {
    },
    members : {
        _cfg: null,
        _form: null,
        _resv: null,
        show: function(reservation){
            var addrId = this._cfg.getAddrId();
            if (!addrId){
                this._cfg.addListenerOnce('addrChanged',function(){
                    this.show(reservation);
                },this);
                var login = new qr.ui.LoginPopup();
                login.show();
                return;
            }
            this.setReservation(reservation);
            this.base(arguments);            
        },
        _updateForm: function(){
            var rpc = qr.data.Server.getInstance();
            var that = this;
            this.setEnabled(false);
            var currencyFormat = new qx.util.format.NumberFormat().set({
                maximumFractionDigits: 2,
                minimumFractionDigits: 2,
                prefix: qr.data.Config.getInstance().getCurrency()+' '
            });
            rpc.callAsyncSmart(function(form){
                if (that._form){
                    that.remove(that._form);
                    that._form.dispose();
                }
                that._form = new qr.ui.AutoForm(form,new qx.ui.layout.VBox(5));
                that.addAt(that._form,0);
                that.setEnabled(true);
                var hold = false;
                var updatePrice = function(e){
                    if (hold){
                        return;
                    }
                    hold = true;
                    var resvForm = e.getData();
                    rpc.callAsyncSmart(function(price){
                        that._form.setData({resv_price: currencyFormat.format(price)});
                        hold = false;
                    },'getPrice',that._mkResv(resvForm));
                };
                that._form.addListener('changeData',updatePrice,that);
            },'getForm','resv');

        },
        _populateForm: function(){
            var row = new qx.ui.container.Composite(new qx.ui.layout.HBox(5,'right'))
            var rpc = qr.data.Server.getInstance();
            var that = this;

            var deleteButton = new qx.ui.form.Button(this.tr("Delete"),'icon/22/actions/dialog-close.png').set({
                width: 50
            });
            row.add(deleteButton,{flex: 1});
            deleteButton.addListener('execute',function(){
                var resvId = this.getReservation().getResvId();
                if (!resvId){
                    return ;
                }
                rpc.callAsyncSmart(function(ret){
                    that.close();
                    qr.ui.Booker.getInstance().reload();
                },'removeEntry','resv',resvId);
            },this);

            var cancelButton = new qx.ui.form.Button(this.tr("Cancel"),'icon/22/actions/dialog-cancel.png').set({
                width: 50
            });
            row.add(cancelButton,{flex: 1});
            cancelButton.addListener('execute',function(){
                this.close();
            },this);

            var sendButton = new qx.ui.form.Button(this.tr("Ok"),'icon/22/actions/dialog-ok.png').set({
                width: 50
            });
            row.add(sendButton,{flex: 1});
            sendButton.addListener('execute',function(){
                if (! this._form.validate() ){
                    return;
                }
                var data = this._form.getData();
                rpc.callAsyncSmart(function(ret){
                    that.close();
                    qr.ui.Booker.getInstance().reload();
                },'putEntry','resv',this.getReservation().getResvId(),this._mkResv(data));
            },this);

            this.addListener('reservationChanged',function(e){
                var resv = e.getData();
                var resvId = resv.getResvId();
                deleteButton.setVisibility( resvId ? 'visible' : 'hidden' );
                var form = this._form;
                form.reset();
                that._resv = null;
                if (resvId){
                    this.setEnabled(false);
                    rpc.callAsyncSmart(function(data){
                        that._resv = data;
                        form.setData(data,true); /* only set fields that are available */
                        that.setEnabled(true);
                    },'getEntry','resv',resvId);
                }
                else {
                    form.setData({resv_price: ''});
                }

            },this);
            this.add(row);
        },
        _mkResv: function(resv){
            var resvObj = this.getReservation();
            var resvRec = this._resv;
            if (! resvRec ){
                var date = resvObj.getStartDate();
                var start = Date.UTC(
                    date.getFullYear(),date.getMonth(),date.getDate(),
                    resvObj.getStartHr(),0,0,0
                );
                resv.resv_start = start/1000;
                resv.resv_len = resvObj.getDuration();
                resv.resv_room = resvObj.getRoomId();
            }
            else {
                for (var key in resvRec){
                    resv[key] = resvRec[key];
                }
            }
            return resv;    
        }
    }    
});
