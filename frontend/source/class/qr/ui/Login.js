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
qx.Class.define("qr.ui.Login", {
    extend : qx.ui.window.Window,
    type: 'singleton',
    construct : function() {                
        this.base(arguments,this.tr('Login'));
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
        
        this.add(this._pupulate);
        this.addListener('appear',function(){this.center()},this);
    },
    properties: {
    },
    events: {        
        login: 'qx.event.Event'
    },
    members : {
        show: function(){
            this.base(arguments);            
        },
        _populate: function(){
            var stack = new qx.ui.container.Stack();
            this.add(stack,{flex: 1});
            var loginForm = new qr.ui.AutoForm([
                {
                    key: 'user_email',      
                    label: this.tr('your eMail address'),                
                    widget: 'text',
                    set: {
                        required: true
                    }
                },
            ],new qx.ui.layout.VBox(5));
            stack.add(loginForm);
            var keyForm = new qr.ui.AutoForm([
                {
                    key: 'key',      
                    label: this.tr('access key'),                
                    widget: 'text',                    
                    set: {
                        required: true
                    }
                },
            ],new qx.ui.layout.VBox(5));
            stack.add(keyForm)
            var userForm = new qr.ui.AutoForm([            
                {
                    key: 'user_first',      
                    label: this.tr('first name'),                
                    widget: 'text',
                    set: {
                        required: true
                    }
                },
                {
                    key: 'user_last',      
                    label: this.tr('last name'),                
                    widget: 'text',
                    set: {
                        required: true
                    }
                },
                {
                    key: 'user_phone1',      
                    label: this.tr('last name'),                
                    widget: 'text',
                    set: {
                        required: true
                    }
                },
                {
                    key: 'addr_org',
                    label: this.tr('organization'),
                    widget: 'text'
                },
                {
                    key: 'addr_addr1',
                    label: this.tr('address line 1'),
                    widget: 'text',
                    set: {
                        required: true
                    }
                },
                {
                    key: 'addr_addr2',
                    label: this.tr('address line 2'),
                    widget: 'text'
                },
                {
                    key: 'addr_zip',
                    label: this.tr('ZIP'),
                    widget: 'text',
                    set: {
                        required: true
                    }
                },
                {
                    key: 'addr_town',
                    label: this.tr('town'),
                    widget: 'text'
                },
                {
                    key: 'addr_cntry',
                    label: this.tr('country'),
                    widget: 'text',
                    set: {
                        required: true
                    }
                },
            ],new qx.ui.layout.VBox(5));
            stack.add(userForm);

            var row = new qx.ui.container.Composite(new qx.ui.layout.HBox(5,'right'))
            var prevButton = new qx.ui.form.Button(this.tr("Back"),'icon/22/actions/go-previous.png').set({
                width: 50
            });
            row.add(prevButton,{flex: 1});
            var nextButton = new qx.ui.form.Button(this.tr("Next"),'icon/22/actions/go-next.png').set({
                width: 50
            });
            row.add(nextButton,{flex: 1});
            
            this.add(row);
            return form;
        }
    }    
});
