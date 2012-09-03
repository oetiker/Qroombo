/* ************************************************************************

   Copyright:
     2010 Guilherme R. Aiolfi

   License:
     LGPL: http://www.gnu.org/licenses/lgpl.html
     EPL: http://www.eclipse.org/org/documents/epl-v10.php
     See the LICENSE file in the project's top-level directory for details.

   Authors:
     * Guilherme R. Aiolfi (guilhermeaiolfi)

************************************************************************ */

/**
 * A widget implementing the token field concept known from Mac OS X
 * @see http://developer.apple.com/mac/library/documentation/Cocoa/Conceptual/TokenField_Guide/Introduction/Introduction.html
 */
qx.Class.define("qr.ui.Token", {
    extend : qx.ui.form.AbstractSelectBox,
    implement : [ qx.ui.core.IMultiSelection, qx.ui.form.IModelSelection ],
    include : [ qx.ui.core.MMultiSelectionHandling, qx.ui.form.MModelSelection ],




    /*
    *****************************************************************************
       EVENTS
    *****************************************************************************
    */

    events : {
        /**
         * This event is fired after a list item was added to the list. The
         * {@link qx.event.type.Data#getData} method of the event returns the
         * added item.
         */
        addItem    : "qx.event.type.Data",


        /**
         * This event is fired after a list item has been removed from the list.
         * The {@link qx.event.type.Data#getData} method of the event returns the
         * removed item.
         */
        removeItem : "qx.event.type.Data",


        /**
         * This event is fired when the widget needs external data. The data dispatched
         * with the event is the string fragment to use to find matching items
         * as the data. The event listener must then load the data from whereever
         * it may come and call populateList() with the string fragment and the
         * received data.
         */
        loadData   : "qx.event.type.Data"
    },




    /*
    *****************************************************************************
       PROPERTIES
    *****************************************************************************
    */

    properties : {
        /**
         *
         */
        orientation : {
            check : [ "horizontal", "vertical" ],
            init  : "vertical",
            apply : "_applyOrientation"
        },


        /**
         *
         */
        appearance : {
            refine : true,
            init   : "token"
        },

        typeInText : {
            check    : "String",
            nullable : true,
            event    : "changeTypeInText",
            init     : "Type in a search term"
        },


        /**
         *
         */
        hintText : {
            check    : "String",
            nullable : true,
            event    : "changeHintText",
            init     : null
        },


        /**
         *
         */
        noResultsText : {
            check    : "String",
            nullable : true,
            init     : "No results"
        },


        /**
         *
         */
        searchingText : {
            check    : "String",
            nullable : true,
            init     : "Searching..."
        },


        /**
         *
         */
        searchDelay : { init : 300 },


        /**
         *
         */
        minChars : { init : 2 },


        /**
         *
         */
        tokenLimit : {
            init     : null,
            nullable : true
        },

        selectOnce : {
            init  : false,
            check : "Boolean"
        },


        /**
         *
         */
        labelPath : { init : "label" },


        /**
         *
         */
        style : { init : "facebook" }
    },




    /*
    *****************************************************************************
       CONSTRUCTOR
    *****************************************************************************
    */

    construct : function() {
        this.base(arguments);

        this.cache = new qr.data.TokenCache();

        this._setLayout(new qx.ui.layout.Flow(3, 3, 'left'));

        var textField = this.getChildControl("textfield");
        var lbl = this.getChildControl("label");
        textField.bind("value", lbl, "value");

        textField.addListener("keypress", function(e) {
            textField.setWidth(lbl.getBounds()["width"] + 8);
        }, this);

        textField.addListener("mousedown", function(e) {
            e.stop();
        });

        this.addListener("click", this._onClick);

        // forward the focusin and focusout events to the textfield. The textfield
        // is not focusable so the events need to be forwarded manually.
        this.addListener("focusin", function(e) {
            textField.fireNonBubblingEvent("focusin", qx.event.type.Focus);
        }, this);

        this.addListener("focusout", function(e) {
            textField.fireNonBubblingEvent("focusout", qx.event.type.Focus);
        }, this);

        textField.setLiveUpdate(true);
        textField.addListener("input", this._onInputChange, this);
        textField.setMinWidth(6);

        this._search = "";
        this._dummy = new qx.ui.form.ListItem();
        this._dummy.setEnabled(false);
        this.setHintText(this.getTypeInText());
        this.bind("hintText", this._dummy, "label");
        this.getChildControl('list').add(this._dummy);
    },




    /*
    *****************************************************************************
       MEMBERS
    *****************************************************************************
    */

    members : {
        SELECTION_MANAGER : qr.ui.TokenSelectionManager,




        /*
        ---------------------------------------------------------------------------
           WIDGET CREATION
        ---------------------------------------------------------------------------
        */

        // overridden
        /**
         * TODOC
         *
         * @param id {var} TODOC
         * @return {null | var} TODOC
         */
        _createChildControlImpl : function(id) {
            var control;

            switch(id)
            {
                case "label":
                    /* the label is used to measure the width of the textfield */

                    control = new qx.ui.basic.Label();
                    this.getApplicationRoot().add(control, {
                        top  : -10,
                        left : -1000
                    });

                    break;

                case "button":
                    /* there is no button element in the tokenfiled */

                    return null;
                    break;

                case "textfield":
                    control = new qx.ui.form.TextField();
                    control.setFocusable(false);
                    control.addState("inner");
                    control.addListener("blur", this.close, this);
                    this._add(control);
                    break;

                case "list":
                    // Get the list from the AbstractSelectBox
                    control = this.base(arguments, id);

                    // Change selection mode
                    control.setSelectionMode("single");
                    break;

                case "popup":
                    control = new qx.ui.popup.Popup(new qx.ui.layout.VBox);
                    control.setAutoHide(true);
                    control.setKeepActive(true);
                    control.addListener("mouseup", this.close, this);
                    control.add(this.getChildControl("list"));
                    control.addListener("changeVisibility", this._onPopupChangeVisibility, this);
                    break;
            }

            return control || this.base(arguments, id);
        },

        // overridden
        /**
         * TODOC
         *
         */
        focus : function() {
            this.base(arguments);
            this.getChildControl("textfield").getFocusElement().focus();
        },

        // overridden
        /**
         * TODOC
         *
         */
        tabFocus : function() {
            var field = this.getChildControl("textfield");

            field.getFocusElement().focus();
        },

        //field.selectAllText();
        /**
         * TODOC
         *
         */
        tabBlur : function() {
            var field = this.getChildControl("textfield");

            field.getFocusElement().blur();
        },

        // overridden
        /**
         * @lint ignoreReferenceField(_forwardStates)
         */
        _forwardStates : { focused : true },




        /*
        ---------------------------------------------------------------------------
           EVENT HANDLERS
        ---------------------------------------------------------------------------
        */

        // overridden
        /**
         * TODOC
         *
         * @param e {Event} TODOC
         */
        _onBlur : function(e) {
            return;
        },


        /**
         * Toggles the popup's visibility.
         *
         * @param e {qx.event.type.Mouse} Mouse click event
         */
        _onClick : function(e) {
            if (this.__selected) {
                this.__selected.removeState("head");
            }

            this.__selected = null;
            this.toggle();
        },

        // overridden
        /**
         * TODOC
         *
         * @param e {Event} TODOC
         */
        _onKeyPress : function(e) {
            var key = e.getKeyIdentifier();
            var list = this.getChildControl("popup");

            if (key == "Down" && !list.isVisible()) {
                this.open();
                e.stopPropagation();
                e.stop();
            }
            else if (key == "Backspace" || key == "Delete") {
                var textfield = this.getChildControl('textfield');
                var value = textfield.getValue();
                var children = this._getChildren();
                var index = children.indexOf(textfield);

                if (value == null || value == "" && !this.__selected) {
                    if (key == "Delete" && index < (children.length - 1)) {
                        this.__selected = children[index + 1];
                        this.__selected.addState("head");
                        this.focus();
                    }
                    else if (key == "Backspace" && index > 0) {
                        this.__selected = children[index - 1];
                        this.__selected.addState("head");
                        this.focus();
                    }
                }
                else if (this.__selected) {
                    this._deselectItem(this.__selected);
                    this.__selected = null;
                    this.tabFocus();
                    e.stop();
                }
            }
            else if (key == "Left" || key == 'Right') {
                var textfield = this.getChildControl('textfield');
                var start = textfield.getTextSelectionStart();
                var length = textfield.getTextSelectionLength();
                var children = this._getChildren();
                var n_children = children.length;

                var item = this.__selected ? this.__selected : textfield;
                var index = children.indexOf(item);

                if (item == textfield) {
                    if (key == 'Left') index -= 1;
                    else index += 1;
                }

                var index_textfield = children.indexOf(textfield);

                if (key == "Left" && index >= 0 && start == 0 && length == 0) {
                    this._addBefore(textfield, children[index]);
                } else if (key == "Right" && index < n_children && start == textfield.getValue().length) {
                    this._addAfter(textfield, children[index]);
                }

                if (this.__selected) {
                    this.__selected.removeState("head");
                }

                this.__selected = null;

                // I really don't know, but FF needs the timer to be able to set the focus right
                // when there is a selected item and the key == 'Left'
                qx.util.TimerManager.getInstance().start(function() {
                    this.tabFocus();
                }, null, this, null, 20);
            }
            else if (key == "Enter" || key == "Space") {
                if (this._preSelectedItem && this.getChildControl('popup').isVisible()) {
                    this._selectItem(this._preSelectedItem);
                    this._preSelectedItem = null;
                    this.toggle();
                }
                else if (key == "Space") {
                    var textfield = this.getChildControl('textfield');
                    textfield.setValue(textfield.getValue() + " ");
                    e.stop();
                }
            }
            else if (key == "Escape") {
                this.close();
            }
            else if (key != "Left" && key != "Right") {
                this.getChildControl("list").handleKeyPress(e);
            }
        },


        /**
         * Event listener for <code>input</code> event on the textfield child
         *
         * @param e {qx.event.type.Data} Data Event
         * @return {boolean} TODOC
         */
        _onInputChange : function(e) {
            var str = e.getData();

            if (str == null || (str != null && str.length < this.getMinChars())) {
                return false;
            }

            var timer = qx.util.TimerManager.getInstance();

            // check for the old listener
            if (this.__timerId != null) {
                // stop the old one
                timer.stop(this.__timerId);
                this.__timerId = null;
            }

            // start a new listener to update the controller
            this.__timerId = timer.start(function() {
                this.search(str);
                this.__timerId = null;
            },
            0, this, null, this.getSearchDelay());
        },

        // overridden
        /**
         * TODOC
         *
         * @param e {Event} TODOC
         */
        _onListMouseDown : function(e) {
            this._selectItem(this._preSelectedItem);
        },

        // overridden
        /**
         * TODOC
         *
         * @param e {Event} TODOC
         */
        _onListChangeSelection : function(e) {
            var current = e.getData();

            if (current.length > 0) {
                // Ignore quick context (e.g. mouseover)
                // and configure the new value when closing the popup afterwards
                var list = this.getChildControl("list");
                var popup = this.getChildControl("popup");
                var context = list.getSelectionContext();

                if (popup.isVisible() && (context == "quick" || context == "key")) {
                    this._preSelectedItem = current[0];
                } else {
                    this._preSelectedItem = null;
                }
            }
        },

        // overridden
        /**
         * TODOC
         *
         * @param e {Event} TODOC
         */
        _onPopupChangeVisibility : function(e) {
            this.tabFocus();
        },




        /*
        ---------------------------------------------------------------------------
           API
        ---------------------------------------------------------------------------
        */

        /**
         * Fire a event to search for a string
         *
         * @param str {String} query to search for
         */
        search : function(str) {
            this.getChildControl('list').removeAll();
            this._dummy.setLabel(this.getSearchingText());
            this.getChildControl('list').add(this._dummy);
            this.open();

            this._search = str;
            this.fireDataEvent("loadData", str);
        },


        /**
         * Populates the list with the data received from the data source
         *
         * @param str {String} The string fragment that was used for retrieving
         *      the autoocomplete data.
         * @param data {Object} A javascript object that contains
         */
        populateList : function(str, data) {
            this.cache.add(str, qx.data.marshal.Json.createModel(data));
            var result = this.cache.get(str);
            var list = this.getChildControl('list');
            list.removeAll();

            if (result.getLength() == 0) {
                this._dummy.setLabel(this.getNoResultsText());
                list.add(this._dummy);
                return;
            }

            for (var i=0; i<result.getLength(); i++) {
                if (!this.getSelectOnce() || (this.getSelectOnce() == true && !this._isSelected(result.getItem(i)))) {
                    var label = result.getItem(i).get(this.getLabelPath());
                    var item = new qx.ui.form.ListItem(this.highlight(label, str));
                    item.setModel(result.getItem(i));
                    item.setRich(true);
                    this.getChildControl('list').add(item);
                }
            }
        },


        /**
         * TODOC
         *
         * @param data {var} TODOC
         * @param selected {var} TODOC
         */
        addToken : function(data, selected) {
            var model = qx.data.marshal.Json.createModel(data);
            var label = model.get(this.getLabelPath());
            var item = new qx.ui.form.ListItem(this.highlight(label, this._search));
            item.setModel(model);
            item.setRich(true);
            var list = this.getChildControl('list');

            if (!this.getSelectOnce() || (this.getSelectOnce() == true && !this._isSelected(model))) {
                if (list.hasChildren() && list.getChildren()[0] == this._dummy) {
                    list.remove(this._dummy);
                }

                list.add(item);
            }

            if (selected && !this._isSelected(model)) {
                this._selectItem(item);
            }
        },


        /**
         * Tests and see if the model is already selected or not
         *
         * @param model {var} Model to be tested
         * @return {boolean} TODOC
         */
        _isSelected : function(model) {
            var selection = this.getModelSelection();

            var item = null, item_model = null;

            for (var i=0; i<selection.getLength(); i++) {
                item = selection.getItem(i);

                if (item && model && item.get(this.getLabelPath()) == model.get(this.getLabelPath())) {
                    return true;
                }
            }

            return false;
        },


        /**
         * Removes an item from the selection
         *
         * @param item {qx.ui.form.ListItem} The List Item to be removed from the selection
         */
        _deselectItem : function(item) {
            if (item && item.constructor == qx.ui.form.ListItem) {
                this.removeFromSelection(item);
                this.fireDataEvent("removeItem", item);
                item.destroy();
            }
        },

        // overridden
        /**
         * TODOC
         *
         * @return {var} TODOC
         */
        getChildrenContainer : function() {
            return this;
        },


        /**
         * Resets the widget
         *
         */
        reset : function() {
            this.getSelection().forEach(function(item) {
                if (item instanceof qx.ui.form.ListItem) {
                    this.removeFromSelection(item);
                    item.destroy();
                }
            },
            this);

            this.getChildren().forEach(function(item) {
                if (item instanceof qx.ui.form.ListItem) {
                    this.remove(item);
                    item.destroy();
                }
            },
            this);

            this.getChildControl('textfield').setValue("");
            this.getChildControl('list').removeAll();
            this.getChildControl('list').add(this._dummy);
        },


        /**
         * Adds an item to the selection
         *
         * @param old {var} TODOC
         */
        _selectItem : function(old) {
            if (old && old.constructor == qx.ui.form.ListItem) {
                var item = this.getSelectOnce() ? old : new qx.ui.form.ListItem();

                item.setAppearance("tokenitem");
                item.setLabel(old.getModel().get(this.getLabelPath()));
                item.setModel(old.getModel());

                item.getChildControl('icon').setAnonymous(false);

                item.getChildControl('icon').addListener("click", function(e) {
                    if (this.__selected) {
                        this.__selected.removeState("head");
                        this.__selected = null;
                    }

                    this._deselectItem(item);
                    e.stop();
                    this.tabFocus();
                },
                this);

                item.addListener("click", function(e) {
                    item.addState("head");

                    if (this.__selected != null && this.__selected != item) {
                        this.__selected.removeState("head");
                    }

                    this.__selected = item;
                    e.stop();
                },
                this);

                item.setIconPosition("right");

                item.getChildControl('icon').addListener("mouseover", function() {
                    item.addState('close');
                });

                item.getChildControl('icon').addListener("mouseout", function() {
                    item.removeState('close');
                });

                if (this.getStyle() != "facebook") {
                    item.getChildControl("label").setWidth(this.getWidth() - 29);
                }

                this._addBefore(item, this.getChildControl('textfield'));
                this.addToSelection(item);
                this.fireDataEvent("addItem", item);

                this.getChildControl('textfield').setValue("");

                //if the selected one was the last one, include dummy item
                if (this.getChildControl('list').getChildren() && this.getChildControl('list').getChildren().length == 0) {
                    this.setHintText(this.getTypeInText());
                    this.getChildControl('list').add(this._dummy);
                }
            }
        },


        /**
         * Highlight the searched string fragment
         *
         * @param value {String} The phrase containing the frament to be highlighted
         * @param query {String} The string fragment that should be highlited
         * @return {String} TODOC
         */
        highlight : function(value, query) {
            return value.replace(new RegExp("(?![^&;]+;)(?!<[^<>]*)(" + query + ")(?![^<>]*>)(?![^&;]+;)", "gi"), "<b>$1</b>");
        }
    },




    /*
     *****************************************************************************
        DESTRUCTOR
     *****************************************************************************
     */

    destruct : function() {
        this._disposeObjects("_dummy", "cache");
    }
});