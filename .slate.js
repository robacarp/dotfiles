S.configAll({
  "defaultToCurrentScreen": true,
  "nudgePercentOf": "screenSize",
  "resizePercentOf": "screenSize",
  "keyboardLayout": "dvorak"
});

S.bind('delete:f6', S.op("relaunch") );

// S.bind('l:f6', S.op("move", {
//         'x': 'screenOriginX',
//         'y': 'screenOriginY',
//         'width': 'screenSizeX',
//         'height': 'screenSizeY',
//       })
//     )

//*

// A weird little microframework for slate.
//
// Because I was bored and really sleepy today. =|
function O_() { return new face() }
function face() {
  this.hsh = {};

  this.x   = function(n){ this.hsh.x = n;      return this; };
  this.y   = function(n){ this.hsh.y = n;      return this; };
  this.w   = function(n){ this.hsh.width = n;  return this; };
  this.h   = function(n){ this.hsh.height = n; return this; };
  this.s   = function(n){ this.hsh.screen = n; return this; };

  this.full = function( ){ return this.x('screenOriginX').y('screenOriginY').w('screenSizeX').h('screenSizeY') }
  this.fin = function( ){ return this.hsh; };
  this.log = function( ){ S.log("{x:" + this.hsh.x + ", y:" + this.hsh.y + ", w:" + this.hsh.width + ", h:" + this.hsh.height + ", s:" + (this.hsh.screen == null ? 'nil' : this.hsh.screen) + "}"); };

  this.full();
  return this;
}

function op(operation, hashback){
  S.log("opp");
  return (
      function (win) {
        var hash = null;
        if (hashback instanceof Function)
          hash = hashback()
        else if (hashback.fin)
          hash = hashback.fin()
        else
          hash = hashback
        // S.log("{x:" + hash.x + ", y:" + hash.y + ", w:" + hash.width + ", h:" + hash.height + ", s:" + (hash.screen == null ? 'nil' : hash.screen) + "}");
        win.doOperation( operation, hash );
      }
  );
}

function mv(to){ return op("move",to); }

// Workstation specific extensions for me
face.prototype.top_major    = function () { return this.h('screenSizeY-150') }
face.prototype.bottom_minor = function () { return this.h(150) }
face.prototype.left_major   = function () { return this.w('screenSizeX-150') }
face.prototype.right_half   = function () { return this.w('screenSizeX/2').x('screenSizeX/2+screenOriginX')  }
face.prototype.left_half    = function () { return this.w('screenSizeX/2').x('screenOriginX')  }
face.prototype.middle_half  = function () { return this.w('screenSizeX/2').x('screenSizeX/4+screenOriginX') }
face.prototype.swap_screen  = function () {
  // this doesn't work...
  // S.log("hup");
  new_screen = (slate.window().screen().id() + 1) % slate.screenCount();
  // S.log("old:" + slate.window().screen().id() + " new:" + new_screen + " ct:" + slate.screenCount());
  return this.s(new_screen)
}

S.bind('1:f6', mv( O_().top_major() ));
S.bind('6:f6', mv( O_().top_major().middle_half() ));
S.bind('9:f6', mv( O_().top_major().left_half() ));
S.bind('0:f6', mv( O_().top_major().right_half() ));

S.bind("':f6", mv( O_() ));
S.bind('f:f6', mv( O_().middle_half() ));
S.bind('r:f6', mv( O_().left_half() ));
S.bind('l:f6', mv( O_().right_half() ));
S.bind('space:f6',mv( O_().swap_screen() ));

/* */

