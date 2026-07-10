import QtQuick 2.12
import NERvGear 1.0 as NVG

NVG.Module {
    initialize: function() {
        console.log("Initializing Games Menu v1.1");
        return true;
    }

    ready: function() {
        console.log("Games Menu v1.1 is ready");
    }

    cleanup: function() {
        console.log("Cleaning up Games Menu v1.1");
    }
}
