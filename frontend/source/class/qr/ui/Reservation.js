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
qx.Class.define("qr.ui.Reservation", {
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
            layout: new qx.ui.layout.VBox(),
            modal: true
        });
        
        this.add(this._mkForm());
        this.addListener('appear',function(){this.center()},this);
    },
    properties: {
    },
    events: {
    },
    members : {
        show: function(reservation,action,context){
            this.base(arguments);            
            this.addListenerOnce('close',function(){
                action.call(context,reservation);
            });
        },
        _mkForm: function(){
            var form = new qr.ui.AutoForm([
                {
                    key: 'room',      
                    label: this.tr('Room'),                
                    widget: 'text',
                    set: {
                        readOnly: true,                        
                        decorator: null
                    }
                },
                {
                    key: 'date',      
                    label: this.tr('Date'),
                    widget: 'text',
                    set: {
                        readOnly: true,
                        decorator: null
                    }
                },
                {
                    key: 'time',      
                    label: this.tr('Time'),                
                    widget: 'text',
                    set: {
                        readOnly: true,
                        decorator: null
                    }
                }, 
                {
                    key: 'bill',      
                    label: this.tr('Billing Address'),                
                    widget: 'selectBox',
                    set: {
                        required: true
                    }
                }, 
                {
                    key: 'price',      
                    label: this.tr('Price'),                
                    widget: 'selectBox',
                    set: {
                        required: true
                    }
                }, 
                {
                    key: 'subject',      
                    label: this.tr('Subject'),                
                    widget: 'comboBox',
                    cfg: {
                        structure: [ 'Sitzung','Schulung' ]
                    },
                    set: {
                        required: true
                    }
                }, 
                {
                    key: 'public',      
                    label: this.tr('Public'),
                    widget: 'checkBox',
                    set: {
                        label: this.tr('Show Subject in Calendar'),
                        required: true
                    }
                },
                {
                    key: 'remark',  
                    label: this.tr('Remark'),                
                    widget: 'textArea',
                    set: {
                        required: true
                    }
                }
                 
            ],new qx.ui.layout.VBox(5));
            var row = new qx.ui.container.Composite(new qx.ui.layout.HBox(5,'right'))
            var deleteButton = new qx.ui.form.Button(this.tr("Delete"),'icon/22/actions/dialog-close.png').set({
                width: 50
            });
            row.add(deleteButton,{flex: 1});
            var cancelButton = new qx.ui.form.Button(this.tr("Cancel"),'icon/22/actions/dialog-cancel.png').set({
                width: 50
            });
            row.add(cancelButton,{flex: 1});
            var sendButton = new qx.ui.form.Button(this.tr("Ok"),'icon/22/actions/dialog-ok.png').set({
                width: 50
            });
            row.add(sendButton,{flex: 1});
            form._add(row);
            form.set({
                allowGrowX: true
            });
            return form;
        }
    }    
});
