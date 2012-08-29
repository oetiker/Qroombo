/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */
/*
#asset(qx/icon/${qx.icontheme}/32/apps/office-calendar.png)
#asset(qx/icon/${qx.icontheme}/32/actions/go-next.png)
#asset(qx/icon/${qx.icontheme}/32/actions/go-previous.png)
*/
/**
  * Booking Navigator
  */
qx.Class.define("qr.ui.Navigator", {
    extend : qx.ui.core.Widget,
    type: 'singleton',
    construct : function() {
        this.base(arguments);
        this._setLayout(new qx.ui.layout.VBox(5,null, "separator-vertical"));
        this.getChildControl('title');
        this._connectListeners();
        this.__chooser.setValue(new Date());
    },
    properties: {
    },
    events: {
    },
    members : { 
        __chooser: null,
        _connectListeners: function(){
            // calendar button
            var calBtn = this.getChildControl('title-datechooser-button');
            var calPop = this.getChildControl('datechooser-popup');
            calBtn.addListener('click',function(e){
                calPop.show();
            },this);
            calBtn.addListener('appear',function(e){
                calPop.show();
            },this);
            var booker =  this.getChildControl('booker');
            var chooser = this.__chooser;
            this.getChildControl('next-button').addListener('execute',function(){
                var date = new Date(chooser.getValue());
                date.setDate(date.getDate()+1);
                chooser.setValue(date);
            },this);
            this.getChildControl('prev-button').addListener('execute',function(){
                var date = new Date(chooser.getValue());
                date.setDate(date.getDate()-1);
                chooser.setValue(date);
            },this);

            // title updater
            var dateFormat = new qx.util.format.DateFormat(this.tr("EEEE, d. LLLL yyyy"));
            chooser.addListener('changeValue',function(e){
                var date = e.getData();
                this.getChildControl('title').setValue(dateFormat.format(date));
                booker.setDate(date);
                calPop.hide();
            },this);            

        },
        _createChildControlImpl : function(id,hash) {
            var control;

            switch(id) {
                case "title-bar":
                    var grid = new qx.ui.layout.Grid();
                    grid.setColumnFlex(1,1);
                    control = new qx.ui.core.Widget();
                    control._setLayout(grid);
                    this._addAt(control,0);
                    break;
                case "title-datechooser-button":
                    control =  new qx.ui.form.Button(null,"icon/32/apps/office-calendar.png");
                    this.getChildControl('title-bar')._add(control,{row:0, column: 0});
                    break;
                case "prev-button":
                    control =  new qx.ui.form.Button(null,"icon/32/actions/go-previous.png");
                    this.getChildControl('title-bar')._add(control,{row:0, column: 2});
                    break;
                case "next-button":
                    control =  new qx.ui.form.Button(null,"icon/32/actions/go-next.png");
                    this.getChildControl('title-bar')._add(control,{row:0, column:3});
                    break;
                case "title":
                    control =  new qx.ui.basic.Label().set({
                        font: 'headline',
                        alignY: 'middle',
                        alignX: 'left',
                        paddingLeft: 20
                    });
                    this.getChildControl('title-bar')._add(control,{row:0, column:1});
                    break;
                case "booker":
                    control =  qr.ui.Booker.getInstance();
                    this._addAt(control,1,{flex: 1});
                    break;
                case "datechooser-popup":
                    control = new qx.ui.popup.Popup(new qx.ui.layout.Grow());
                    var calBtn = this.getChildControl('title-datechooser-button');
                    calBtn.addListenerOnce('appear',function(e){
                        control.placeToWidget(calBtn,true);
                    },this);
                    var chooser = this.__chooser = new qx.ui.control.DateChooser();
                    control.add(chooser);
                    break;
            }                  
            return control || this.base(arguments, id);
        }            
    }
});
