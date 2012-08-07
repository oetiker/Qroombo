/* ************************************************************************

   Copyright:

   License:

   Authors:

************************************************************************ */

qx.Theme.define("qr.theme.Appearance", {
    extend      : qx.theme.indigo.Appearance,
    appearances : {
        "datechooser/day" : {
            style : function(states) {
                return {
                    textAlign       : "center",
                    decorator       : states.today ? "main" : "main-background",
                    textColor       : states.disabled ? "text-disabled" : states.selected ? "text-selected" : states.otherMonth ? "text-disabled" : undefined,
                    backgroundColor : states.disabled ? undefined : states.selected ? "background-selected" : undefined,
                    padding         : [ 2, 3 ],
                    cursor          : 'pointer'
                };
            }
        },
    "datechooser/weekday" :
    {
      style : function(states)
      {
        return {
          decorator       : "datechooser-weekday",
          textAlign       : "center",
          textColor       : states.disabled ? "text-disabled" : "background-selected-dark",
          backgroundColor : states.weekend ? "background" : "light-background",
          paddingTop: 2
        };
      }
    },
"datechooser" :
    {
      style : function(states)
      {
        return {
          decorator : "main",
          minWidth: 300
        }
      }
    }


    }
});
