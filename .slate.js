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
  this.stack = [];

  // Slate executes javascript ahead of time unless you bind an action to a closure.
  // As such, we want to actually execute much later than when creating key bindings,
  // so that we can do more advanced operations.
  //
  // These wrappers provide a syntactic sugar which creates closures that modify
  // a windows position and size.
  this.x   = function(n){ this.stack.push( function(){ this.hsh.x = n;      }); return this; };
  this.y   = function(n){ this.stack.push( function(){ this.hsh.y = n;      }); return this; };
  this.w   = function(n){ this.stack.push( function(){ this.hsh.width  = n; }); return this; };
  this.h   = function(n){ this.stack.push( function(){ this.hsh.height = n; }); return this; };
  this.s   = function(n){ this.stack.push( function(){ this.hsh.screen = n; }); return this; };

  // These more meta functions dont need to push anything to the transform stack directly
  // since they just call the helpers above directly.
  this.full = function( ){ return this.x('screenOriginX').y('screenOriginY').w('screenSizeX').h('screenSizeY') }
  this.fin  = function( ){ return this.hsh; };
  this.log  = function( ){ S.log("{x:" + this.hsh.x + ", y:" + this.hsh.y + ", w:" + this.hsh.width + ", h:" + this.hsh.height + ", s:" + (this.hsh.screen == null ? 'nil' : this.hsh.screen) + "}"); };

  // Shortcuts for different actions
  this.mv = function( ){ S.log('creating closure'); return this.op('move'); }

  // Essentially a private function, you probably shouldn't be calling this.
  // This provides a closure for Slate to execute when bound to a hotkey.
  // Inside the closure, we execute the transformation stack to build the hash
  // and then pass that has on to window.doOperation.
  this.op = function(operation){
    var that = this;
    return (
        function(win) {
          for (var i=0; i < that.stack.length; i ++)
            that.stack[i].call(that);

          win.doOperation(operation, that.fin());
        }
    );
  }

  this.full();
  return this;
}

// Workstation specific extensions for me
face.prototype.top_major    = function () { S.log('top_major'); return this.h('screenSizeY-150') }
face.prototype.bottom_minor = function () { return this.h(150) }
face.prototype.left_major   = function () { return this.w('screenSizeX-150') }
face.prototype.right_half   = function () { return this.w('screenSizeX/2').x('screenSizeX/2+screenOriginX')  }
face.prototype.left_half    = function () { return this.w('screenSizeX/2').x('screenOriginX')  }
face.prototype.middle_half  = function () { S.log('middle_half'); return this.w('screenSizeX/2').x('screenSizeX/4+screenOriginX') }
face.prototype.swap_screen  = function () {
  // this doesn't work...
  S.log("calling swap_screen");
  new_screen = (slate.window().screen().id() + 1) % slate.screenCount();
  S.log("old:" + slate.window().screen().id() + " new:" + new_screen + " ct:" + slate.screenCount());
  return this.s(new_screen)
}

S.bind('1:f6', O_().top_major().mv() );
S.bind('6:f6', O_().top_major().middle_half().mv() );
S.bind('9:f6', O_().top_major().left_half().mv() );
S.bind('0:f6', O_().top_major().right_half().mv() );

S.bind("`:f6", O_().mv());
S.bind('f:f6', O_().middle_half().mv());
S.bind('r:f6', O_().left_half().mv());
S.bind('l:f6', O_().right_half().mv());
S.bind('space:f6', O_().swap_screen().mv());

/* */

