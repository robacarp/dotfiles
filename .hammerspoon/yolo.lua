local Mutation = require('mutation')

-- modalyolo keeps track of bindings and allows us to wrap all events
local ModalYoLo = {}
function ModalYoLo:new(modal_key)
  local obby = {
    binding = hs.hotkey.modal.new('',modal_key)
  }

  -- disable binding on escape key
  obby.binding:bind('', 'escape', function()
    obby.binding:exit()
  end)

  -- automatically disable modal key after 1 second
  function obby.binding:entered()
    hs.timer.doAfter(1, function()
      obby.binding:exit()
    end)
  end

  self.__index = self
  return setmetatable(obby, self)
end

  -- bind a key to an action under the modal
  function ModalYoLo:bind(key, mutator)
    self.binding:bind('', key, function()
      self.binding:exit()
      mutator(Mutation:new())
    end)
  end

return ModalYoLo
