/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/*
#asset(qr/loader.gif)
*/

/**
  * calendar widget, showing a days reservations
  */
qx.Class.define("qr.ui.Booker", {
    extend : qx.ui.core.Widget,
    type : 'singleton',

    construct : function() {
        this.base(arguments);
        this.set({ backgroundColor : 'white-box-border' });
        this._cfg = qr.data.Config.getInstance();
        this._setLayout(new qx.ui.layout.Canvas());
        this._reservationMap = {};
        this._activeMarkerStack = [];
        this._otherMarkerStack = [];
        this._occupyMap = {};
        this._rowToRoomId = {};
        this._populate();
        this._createChildControl('busy');
        this._addMouse();
    },

    properties : {
        date : {
            check : 'Date',
            apply : '_applyDate',
            init  : new Date()
        }
    },

    events : { cleardrag : 'qx.event.type.Event' },

    members : {
        _colWgt : null,
        _rowWgt : null,
        _reservationMap : null,
        _occupyMap : null,
        _activeMarkerStack : null,
        _otherMarkerStack : null,
        _cfg : null,
        _rowToRoomId : null,


        /**
         * TODOC
         *
         */
        clearReservations : function() {
            var overlay = this.getChildControl('overlay');

            for (var key in this._reservationMap) {
                var item = this._reservationMap[key];
                overlay._remove(item);

                if (item.getUserData('reservation').getEditable()) {
                    this._activeMarkerStack.push(item);
                } else {
                    this._otherMarkerStack.push(item);
                }

                delete this._reservationMap[key];
            }

            this._occupyMap = {};
        },


        /**
         * TODOC
         *
         * @param reservation {var} TODOC
         */
        addReservation : function(reservation) {
            var bookerDate = this.getDate().getTime() / 1000;

            if (!reservation.dateMatch(this.getDate())) {
                return;
            }

            var marker = this._mkMarker(reservation);
            var overlay = this.getChildControl('overlay');
            var row = reservation.getRow();
            var col = reservation.getColumn();
            var span = reservation.getColSpan();

            overlay._add(marker, {
                row     : row,
                column  : col,
                colSpan : span
            });

            for (var i=col; i<col+span; i++) {
                this._occupyMap[String(i) + ':' + String(row)] = true;
            }
        },


        /**
         * TODOC
         *
         * @param reservationId {var} TODOC
         */
        removeReservation : function(reservationId) {
            var overlay = this.getChildControl('overlay');
            var item = this._reservationMap[reservationId];
            var reservation = item.getUserData('reservation');
            var row = reservation.getRow();
            var col = reservation.getColumn();
            var span = reservation.getColSpan();

            for (var i=col; i<col+span; i++) {
                this._occupyMap[String(i) + ':' + String(row)] = false;
            }

            overlay._remove(item);
        },


        /**
         * TODOC
         *
         */
        reload : function() {
            this._applyDate(this.getDate());
        },


        /**
         * TODOC
         *
         * @param reservation {var} TODOC
         * @return {var} TODOC
         */
        _mkMarker : function(reservation) {
            var marker;

            if (reservation.getEditable()) {
                if (this._activeMarkerStack.length) {
                    marker = this._activeMarkerStack.pop();
                }
                else {
                    marker = new qx.ui.basic.Atom().set({
                        backgroundColor : '#eef',
                        center          : true,
                        cursor          : 'pointer',
                        width           : 20
                    });

                    marker.addListener('mouseover', function() {
                        marker.setBackgroundColor('#eff');
                    });

                    marker.addListener('mouseout', function() {
                        marker.setBackgroundColor('#eef');
                    });

                    var popup = qr.ui.ReservationPopup.getInstance();
                    marker.addListener('click', function() {
                        popup.show(marker.getUserData('reservation').getResvId());
                    },
                    this);
                }
            }
            else {
                if (this._otherMarkerStack.length) {
                    marker = this._otherMarkerStack.pop();
                }
                else {
                    marker = new qx.ui.basic.Atom().set({
                        backgroundColor : '#eee',
                        center          : true
                    });
                }
            }

            this._reservationMap[reservation.getResvId()] = marker;
            marker.setUserData('reservation', reservation);
            marker.setLabel(String(reservation.getStartHr()) + ' - ' + String(reservation.getDuration() + reservation.getStartHr()));
            return marker;
        },

        /**
         * TODOC
         *
         * @param id {var} TODOC
         * @return {var} TODOC
         */
        _createChildControlImpl : function(id) {
            var control;

            switch(id)
            {
                case 'grid':

                case 'overlay':
                    control = new qx.ui.core.Widget();
                    var grid = new qx.ui.layout.Grid(1, 1);
                    control._setLayout(grid);
                    break;

                case 'busy':
                    control = new qx.ui.basic.Atom(this.tr('loading calendar ...'), "qr/loader.gif").set({
                        visibility      : 'hidden',
                        backgroundColor : '#ffffff',
                        textColor       : '#bfbfbf',
                        allowGrowX      : true,
                        allowGrowY      : true,
                        allowShrinkX    : true,
                        allowShrinkY    : true,
                        alignX          : 'center',
                        alignY          : 'middle',
                        center          : true
                    });

                    break;
            }

            this._add(control, {
                left   : 0,
                top    : 0,
                right  : 0,
                bottom : 0
            });

            return control || this.base(arguments, id);
        },


        /**
         * TODOC
         *
         */
        _populate : function() {
            var that = this;
            this._rowWgt = [];
            var grid = this.getChildControl('grid');
            var gridLayout = grid._getLayout();
            var overlay = this.getChildControl('overlay');
            var overlayLayout = overlay._getLayout();

            grid._add(this._mkCell(null, 'background'), {
                row    : 0,
                column : 0
            });

            var roomIds = this._cfg.getRoomList();

            roomIds.forEach(function(room, row) {
                var roomInfo = this._cfg.getRoomInfo(room);
                var rl = that._mkCell(roomInfo.name, 'background').set({ padding : [ 5, 5, 5, 10 ] });
                this._rowToRoomId[row + 1] = room;
                that._rowWgt.push(rl);

                grid._add(rl, {
                    row    : row + 1,
                    column : 0
                });

                gridLayout.setRowFlex(row + 1, 1);
                overlayLayout.setRowFlex(row + 1, 1);

                overlay._add(that._mkCell(), {
                    row    : row + 1,
                    column : 0
                });
            },
            this);

            this._colWgt = [];
            gridLayout.setColumnWidth(0, 130);
            overlayLayout.setColumnWidth(0, 130);
            var start = this._cfg.getFirstHour();
            var end = this._cfg.getLastHour();

            for (var hour=start, col=1; hour<end; col++, hour++) {
                var cl = this._mkCell(String(hour) + ' - ' + String(hour + 1), 'background');
                cl.setTextAlign('center');
                that._colWgt.push(cl);

                grid._add(cl, {
                    row    : 0,
                    column : col
                });

                overlay._add(this._mkCell(), {
                    row    : 0,
                    column : col
                });

                gridLayout.setColumnFlex(col, 1);
                overlayLayout.setColumnFlex(col, 1);
                gridLayout.setColumnWidth(col, 30);
                overlayLayout.setColumnWidth(col, 30);

                roomIds.forEach(function(room, row) {
                    var cell = that._mkCell(null, 'background');

                    grid._add(cell, {
                        row    : row + 1,
                        column : col
                    });
                });
            }
        },


        /**
         * TODOC
         *
         * @param text {var} TODOC
         * @param bgColor {var} TODOC
         * @return {var} TODOC
         */
        _mkCell : function(text, bgColor) {
            var cell = new qx.ui.basic.Label().set({
                allowGrowX    : true,
                allowGrowY    : true,
                minWidth      : 50,
                paddingTop    : 2,
                paddingBottom : 2
            });

            if (bgColor) {
                cell.setBackgroundColor(bgColor);
            }

            if (text) {
                cell.setValue(text);
            }

            return cell;
        },


        /**
         * TODOC
         *
         */
        clearDragMarker : function() {
            var overlay = this.getChildControl('overlay');
            overlay._remove(this._dragMarker);
        },


        /**
         * TODOC
         *
         */
        _addMouse : function() {
            var start;
            var begin;
            var len;
            var down = false;
            var overlay = this.getChildControl('overlay');

            var drag = this._dragMarker = new qx.ui.basic.Atom().set({
                backgroundColor : '#fee',
                center          : true,
                allowGrowX      : true,
                allowShrinkX    : true
            });

            var firstHr = this._cfg.getFirstHour();

            this.addListener('mousedown', function(e) {
                start = this._posToGrid(e);

                if (this._occupyMap[String(start.col) + ':' + String(start.row)]) {
                    return;
                }

                this.capture();

                overlay._add(drag, {
                    column  : start.col,
                    row     : start.row,
                    colSpan : 1
                });

                begin = start.col + firstHr - 1;
                len = 1;
                drag.setLabel(String(begin) + ' - ' + String(begin + len));
                down = true;
            },
            this);

            var popup = qr.ui.ReservationPopup.getInstance();
            var cfg = qr.data.Config.getInstance();

            popup.addListener('close',this.reload,this);

            this.addListener('mouseup', function(e) {
                if (down) {
                    down = false;

                    if (cfg.getAddrId()) {
                        popup.addListenerOnce('close', function() {
                            this.fireEvent('cleardrag');
                        }, this);

                        popup.show(new qr.data.Reservation().set({
                            startDate : this.getDate(),
                            startHr   : begin,
                            duration  : len,
                            roomId    : this._rowToRoomId[start.row],
                            editable  : true
                        }).getResvRec());
                    }
                    else {
                        qr.ui.LoginPopup.getInstance().show();
                        this.fireEvent('cleardrag');
                    }
                }
            },
            this);

            this.addListener('mousemove', function(e) {
                if (down) {
                    var cell = this._posToGrid(e);

                    if (cell.col < start.col) {
                        for (var col=cell.col; col<=start.col; col++) {
                            if (this._occupyMap[String(col) + ':' + String(start.row)]) {
                                return;
                            }
                        }

                        begin = cell.col + firstHr - 1;
                        len = start.col - cell.col + 1;

                        overlay._add(drag, {
                            column  : cell.col,
                            row     : start.row,
                            colSpan : len
                        });
                    }
                    else {
                        for (var col=start.col; col<=cell.col; col++) {
                            if (this._occupyMap[String(col) + ':' + String(start.row)]) {
                                return;
                            }
                        }

                        len = cell.col - start.col + 1;

                        overlay._add(drag, {
                            column  : start.col,
                            row     : start.row,
                            colSpan : len
                        });
                    }

                    drag.setLabel(String(begin) + ' - ' + String(begin + len));
                }
            },
            this);

            this.addListener('cleardrag', function(e) {
                if (drag.getLayoutParent()) {
                    overlay._remove(drag);
                }
            });
        },


        /**
         * TODOC
         *
         * @param e {Event} TODOC
         * @return {Map} TODOC
         */
        _posToGrid : function(e) {
            var left = e.getDocumentLeft();
            var top = e.getDocumentTop();
            var col = 0;
            var row = 0;

            this._colWgt.forEach(function(wgt, c) {
                var el = wgt.getContainerElement().getDomElement();

                if (el) {
                    var pos = qx.bom.element.Location.get(el);

                    if (pos.left <= left) {
                        col = c;
                    }
                }
            });

            this._rowWgt.forEach(function(wgt, r) {
                var el = wgt.getContainerElement().getDomElement();

                if (el) {
                    var pos = qx.bom.element.Location.get(el);

                    if (pos.top <= top) {
                        row = r;
                    }
                }
            });

            return {
                col : col + 1,
                row : row + 1
            };
        },


        /**
         * TODOC
         *
         * @param newDate {var} TODOC
         * @param oldDate {var} TODOC
         */
        _applyDate : function(newDate, oldDate) {
            this.clearReservations();
            var busy = this.getChildControl('busy');

            var timer = qx.event.Timer.once(function() {
                busy.show();
            }, this, 1000);

            var that = this;
            var rpc = qr.data.Server.getInstance();

            rpc.callAsyncSmart(function(ret) {
                ret.forEach(function(resv) {
                    that.addReservation(new qr.data.Reservation(resv));
                });

                timer.stop();
                busy.hide();
            },
            'getCalendarDay', Date.UTC(newDate.getUTCFullYear(), newDate.getUTCMonth(), newDate.getUTCDate(), 0, 0, 0) / 1000);
        }
    }
});
