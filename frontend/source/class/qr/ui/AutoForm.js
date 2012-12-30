/* ************************************************************************

   Copyrigtht: OETIKER+PARTNER AG
   License:    GPLv3 or later
   Authors:    Tobias Oetiker
   Utf8Check:  äöü

************************************************************************ */

/**
 * Create a form. The argument to the form
 * widget defines the structure of the form.
 *     
 *     [
 *         {
 *           key: 'xyc',             // unique name
 *           label: 'label',    
 *           widget: 'text',
 *           cfg: {},                // widget specific configuration
 *           set: {}                 // normal qx porperties to apply
 *          },
 *          ....
 *     ]
 * 
 * The following widgets are supported: date, text, selectbox
 * 
 *     text: { },
 *     selectBox: { cfg { structure: [ {key: x, title: y}, ...] } },
 *     date: { },                    // following unix tradition, dates are represented in epoc seconds
 *
 * Populate the new form using the setDate method, providing a map
 * with the required data.
 * 
 */
qx.Class.define("qr.ui.AutoForm", {
    extend : qx.ui.core.Widget,


    /**
     * @param structure {Array} form structure
     * @param layout {Incstance} qooxdoo layout instance
     * @param formRenderer {Class} formRenderer class
     */
    construct : function(structure, layout, renderer) {
        this.base(arguments);
        this._setLayout(layout || new qx.ui.layout.Grow());
        var form = this._form = new qx.ui.form.Form();
        this._ctrl = {};
        var formCtrl = new qx.data.controller.Form(null, form);
        this._boxCtrl = {};
        var tm = this._typeMap = {};

        for (var i=0; i<structure.length; i++) {
            var s = structure[i];

            if (s.key == null) {
                throw new Error('the key property is required');
            }

            if (s.widget == 'header') {
                form.addGroupHeader(s.label);
                continue;
            }

            var cfg = s.cfg || {};
            var control;

            switch(s.widget)
            {
                case 'date':
                    control = new qx.ui.form.DateField().set({
                        value       : null,
                        dateFormat  : new qx.util.format.DateFormat(this.tr("dd.MM.yyyy")),
                        placeholder : 'now'
                    });

                    tm[s.key] = 'date';
                    break;

                case 'text':
                    control = new qx.ui.form.TextField();
                    tm[s.key] = 'text';
                    break;

                case 'textArea':
                    control = new qx.ui.form.TextArea();
                    tm[s.key] = 'text';
                    break;

                case 'checkBox':
                    control = new qx.ui.form.CheckBox();
                    tm[s.key] = 'bool';
                    break;

//                case 'tokenField':
//                    control = new qr.ui.TokenField();                    
//                    tm[s.key] = 'tokenArray';
//                    break;

                case 'selectBox':
                    control = new qx.ui.form.SelectBox();
                    var ctrl = this._boxCtrl[s.key] = new qx.data.controller.List(null, control, 'title');
                    ctrl.setDelegate({
                        bindItem : function(controller, item, index) {
                            controller.bindProperty('key', 'model', null, item, index);
                            controller.bindProperty('title', 'label', null, item, index);
                        }
                    });

                    var sbModel = qx.data.marshal.Json.createModel(cfg.structure ||
                    [ {
                        title : '',
                        key   : null
                    } ]);

                    ctrl.setModel(sbModel);
                    break;

                case 'comboBox':
                    control = new qx.ui.form.ComboBox();
                    var ctrl = this._boxCtrl[s.key] = new qx.data.controller.List(null, control);
                    var sbModel = qx.data.marshal.Json.createModel(cfg.structure || []);
                    ctrl.setModel(sbModel);
                    break;

                default:
                    throw new Error("unknown widget type " + s.widget);
                    break;
            }

            if (s.set) {
                control.set(s.set);
            }

            this._ctrl[s.key] = control;
            form.add(control, s.label, null, s.key);

            if (s.widget == 'date') {
                formCtrl.addBindingOptions(s.key, {
                    converter : function(data) {
                        if (/^\d+$/.test(String(data))) {
                            var d = new Date();
                            d.setTime(parseInt(data) * 1000);
                            return d;
                        }

                        return null;
                    }
                },
                {
                    converter : function(data) {
                        if (qx.lang.Type.isDate(data)) {
                            return Math.round((data.getTime() / 1000));
                        }

                        return null;
                    }
                });
            }
        }

        var model = this._model = formCtrl.createModel(true);

        model.addListener('changeBubble', function(e) {
            if (!this._settingData) {
                this.fireDataEvent('changeData', this.getData());
            }
        },
        this);

        var formWgt = new (renderer || qx.ui.form.renderer.Single)(form);
        var fl = formWgt.getLayout();

        // have plenty of space for input, not for the labels
        fl.setColumnFlex(0, 0);
        fl.setColumnWidth(0, 130);
        fl.setColumnFlex(1, 1);
        fl.setColumnMinWidth(1, 130);
        this._add(formWgt);
    },

    events : {
        /**
         * fire when the form changes content and
         * and provide access to the data
         */
        changeData : 'qx.event.type.Data'
    },

    members : {
        _boxCtrl : null,
        _ctrl : null,
        _form : null,
        _model : null,
        _settingData : false,
        _typeMap : null,


        /**
         * TODOC
         *
         * @return {var} TODOC
         */
        validate : function() {
            return this._form.validate();
        },


        /**
         * TODOC
         *
         */
        reset : function() {
            this._form.reset();
        },


        /**
         * get a handle to the control with the given name
         *
         * @param key {var} TODOC
         * @return {var} TODOC
         */
        getControl : function(key) {
            return this._ctrl[key];
        },


        /**
         * fetch the data for this form
         *
         * @return {var} TODOC
         */
        getData : function() {
            return this._getData(this._model);
        },


        /**
         * load new data into the data main model
         *
         * @param data {var} TODOC
         * @param relax {var} TODOC
         */
        setData : function(data, relax) {
            this._setData(this._model, data, relax);
        },


        /**
         * set the data in a selectbox
         *
         * @param box {var} TODOC
         * @param data {var} TODOC
         */
        setSelectBoxData : function(box, data) {
            var model;
            this._settingData = true;

            if (data.length == 0) {
                model = qx.data.marshal.Json.createModel([ {
                    title : '',
                    key   : null
                } ]);
            }
            else {
                model = qx.data.marshal.Json.createModel(data);
            }

            this._boxCtrl[box].setModel(model);
            this._boxCtrl[box].getTarget().resetSelection();
            this._settingData = false;
        },


        /**
         * load new data into a model
         * if relax is set unknown properties will be ignored
         *
         * @param model {var} TODOC
         * @param data {var} TODOC
         * @param relax {var} TODOC
         */
        _setData : function(model, data, relax) {
            this._settingData = true;

            for (var key in data) {
                var upkey = qx.lang.String.firstUp(key);
                var setter = 'set' + upkey;
                var getter = 'get' + upkey;
                var value = data[key];

                if (relax && !model[setter]) {
                    continue;
                }

                switch(this._typeMap[key])
                {
                    case 'text':
                        model[setter](String(value));
                        break;

                    case 'bool':
                        model[setter](qx.lang.Type.isBoolean(value) ? value : parseInt(value) != 0);
                        break;

                    case 'date':
                        model[setter](new Date(value));
                        break;

                    default:
                        model[setter](qx.lang.Type.isNumber(model[getter]()) ? parseInt(value) : value);
                        break;
                }
            }

            this._settingData = false;

            /* only fire ONE if there was an attempt at change */

            this.fireDataEvent('changeData', this.getData());
        },


        /**
         * turn a model object into a plain data structure
         *
         * @param model {var} TODOC
         * @return {var} TODOC
         */
        _getData : function(model) {
            var props = model.constructor.$$properties;
            var data = {};

            for (var key in props) {
                var getter = 'get' + qx.lang.String.firstUp(key);
                data[key] = model[getter]();
            }

            return data;
        }
    }
});
