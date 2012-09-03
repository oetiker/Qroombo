/* ************************************************************************

   Copyright:

   License:

   Authors:

************************************************************************ */

qx.Theme.define("qr.theme.Decoration", {
    extend : qx.theme.indigo.Decoration,

    decorations : {
        "main-background" : {
            decorator : qx.ui.decoration.Uniform,

            style : {
                width : 1,
                color : "background"
            }
        },

        'tokenitem' : {
            decorator : [ qx.ui.decoration.MBorderRadius, qx.ui.decoration.MSingleBorder, qx.ui.decoration.MBackgroundColor ],

            style : {
                radius          : 5,
                width           : 1,
                color           : "button-border",
                backgroundColor : "button-box-bright"
            }
        },

        'tokenitem-hovered' : {
            include : 'tokenitem',
            style   : { color : "button-border-hovered" }
        }
    }
});