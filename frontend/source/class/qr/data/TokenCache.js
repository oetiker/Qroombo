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
 * A class to cache ...
 */
qx.Class.define("qr.data.TokenCache", {
    extend : qx.core.Object,

    properties : {
        maxSize : {
            init  : 50,
            event : "changeMaxSize"
        }
    },

    construct : function(max_size) {
        if (max_size) {
            this.setMaxSize(50);
        }

        this._data = {};
        this._size = 0;
    },

    members : {
        /**
         * TODOC
         *
         */
        flush : function() {
            this._data = {};
            this._size = 0;
        },


        /**
         * TODOC
         *
         * @param query {var} TODOC
         * @param results {var} TODOC
         */
        add : function(query, results) {
            if (this._size > this.getMaxSize()) {
                this.flush();
            }

            if (!this._data[query]) {
                this._size++;
            }

            this._data[query] = results;
        },


        /**
         * TODOC
         *
         * @param query {var} TODOC
         * @return {var} TODOC
         */
        get : function(query) {
            return this._data[query];
        }
    }
});