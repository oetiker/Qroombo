/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/*
#asset(qx/icon/${qx.icontheme}/16/actions/go-next.png)
*/

/**
  * get details on booking
  */
qx.Class.define("qr.ui.LoginPopup", {
    extend : qx.ui.window.Window,
    type : 'singleton',

    construct : function() {
        this.base(arguments, this.tr('Login'));

        this.set({
            allowClose    : true,
            allowMaximize : false,
            allowMinimize : false,
            showClose     : true,
            showMaximize  : false,
            showMinimize  : false,
            showStatusbar : false,
            width         : 400,
            layout        : new qx.ui.layout.VBox(15),
            modal         : true
        });

        this.add(new qx.ui.basic.Label(this.tr('You have to login, to make reservations. Enter your eMail address and press the Next button below.')).set({
            rich       : true,
            paddingTop : 10
        }));

        this._addForm();
    },

    members : {
        /**
         * TODOC
         *
         */
        _addForm : function() {
            var form = new qr.ui.AutoForm([ {
                key    : 'email',
                label  : this.tr('eMail'),
                widget : 'text',
                set    : { required : true }
            } ],
            new qx.ui.layout.VBox(5));

            var row = new qx.ui.container.Composite(new qx.ui.layout.HBox(5, 'right'));
            var nextButton = new qx.ui.form.Button(this.tr("Next"), 'icon/16/actions/go-next.png').set({ iconPosition : 'right' });
            var rpc = qr.data.Server.getInstance();
            var that = this;

            nextButton.addListener('execute', function() {
                if (!form.validate()) {
                    return;
                }

                var data = form.getData();

                rpc.callAsyncSmart(function(ret) {
                    that.close();
                    var keyPop = new qr.ui.KeyPopup(ret);
                    keyPop.open();
                },
                'sendKey', data.email);
            },
            this);

            row.add(nextButton);
            this.add(form);
            var emailCtrl = form.getControl('email');

            emailCtrl.addListener('keyup', function(e) {
                if (e.getKeyIdentifier() == 'Enter') {
                    nextButton.execute();
                }
            });

            this.addListener('appear', function() {
                this.center();
                emailCtrl.focus();
            },
            this);

            this.add(row);
        }
    }
});