/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/**
  * calendar widget, showing a days bookings
  */
qx.Class.define("qr.ui.Booker", {
    extend : qx.ui.core.Widget,
    construct : function() {                
        this.base(arguments);
        this.set({
            backgroundColor: 'black'
        });
        this._setLayout(new qx.ui.layout.Grid(1,1));
        this._cols = [ 'Salon', 'Küche', 'Sitzung', 'Bernstein', 'Rose','Flora'];
        this._rows = [];
        for (var slot=7;slot<=23;slot++){
	   this._rows.push(String(slot)+'-'+String(slot+1));
        }
        this._populate();
        this._addMouse();
    },
    properties: {
    },
    events: {
    },
    members : {
        _rows: null,
        _cols: null,
        _colWgt: null,
        _rowWgt: null,
        _populate: function(){
            var that = this;
	    this._rowWgt = [];
            this._rows.forEach(function(slot,row){                
                var rl = new qx.ui.basic.Label(slot).set({
                    padding: [ 2,3,3,2],
                    backgroundColor: '#fff',
                    allowGrowX: true,
                    allowGrowY: true,
		    textAlign: 'center'
                });
                that._rowWgt.push(rl);
                that._add(rl,{row: row+1,column: 0});
	    });
            this._colWgt = [];
            this._cols.forEach(function(room,col){                
                var cl =  new qx.ui.basic.Label(room).set({   
                    padding: [ 2,3,3,2],
                    backgroundColor: '#fff',
                    allowGrowX: true,
                    allowGrowY: true
                });
                that._colWgt.push(cl);                
                that._add(cl,{row: 0,column: col+1});
	    });
        },
        _addMouse: function(){	    
	    var drag = new qx.ui.basic.Label('*').set({
                backgroundColor: '#fff',
                allowGrowX: true,
                allowGrowY: true
            });
	    var start;
	    var down = false;
            this.addListener('mousedown',function(e){
                start = this._posToGrid(e);
                down = true;
	    },this);
            this.addListener('mouseup',function(e){
                down = false
	    },this);
            this.addListener('mousemove',function(e){
                if (down){
                    var cell = this._posToGrid(e);
		    if (cell.row < start.row){
                        var tmp = cell.row;
                        cell.row = start.row;
                        start.row = tmp;
		    }
                    this._add(drag,{column: start.col+1,row: start.row+1,rowSpan: cell.row - start.row + 1});
                }
	    },this);
        },
        _posToGrid: function(e){
            var left = e.getDocumentLeft();
            var top = e.getDocumentTop();
            var col = 0;
            var row = 0;
            this._colWgt.forEach(function(wgt,c){
                var el = wgt.getContainerElement().getDomElement();
                if (el){
                    var pos = qx.bom.element.Location.get(el);
                    if (pos.left <= left){
                        col = c;
                    }
                }
            });
            this._rowWgt.forEach(function(wgt,r){
                var el = wgt.getContainerElement().getDomElement();
                if (el){
                    var pos = qx.bom.element.Location.get(el);
	            if (pos.top <= top){
                        row = r;
                    }
                }
            });
	    return {col:col,row:row};
        }
    }
});
