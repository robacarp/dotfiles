local json = require('downloaded_modules/dkjson')
local inspect = require('downloaded_modules/inspect')
local Workspace = require('toggl/workspace')

local Toggl = {}

function Toggl:new(config)
  local toggle = {
    base_url = 'https://www.toggl.com/api/v8',
    api_key  = nil,
    username = nil,
    password = nil,

    workspaces = {},
    projects = {},
    clients = {}
  }

  -- toggle.base_url = 'http://localhost:2399'

  for k,v in pairs(config) do toggle[k] = v end

  self.__index = self
  local object = setmetatable(toggle, self)

  return object
end

  function Toggl:fetch_api_key()
    local response, success = self:_get('me')

    if success then
      return response.data.api_token
    end
  end

  function Toggl:get_workspaces()
    local response, success = self:_get('workspaces')
    if not success then return {} end
    self.workspaces = {}
    for i, toggl_workspace in pairs(response) do
      workspace = Workspace:new(toggl_workspace)
      table.insert(self.workspaces, workspace)
    end
    return self.workspaces
  end

  function Toggl:get_clients()
    self:_get('')
  end

  function Toggl:_encode_authentication()
    if self.username and self.password then
      return hs.base64.encode(self.username .. ':' .. self.password)
    elseif self.api_key then
      return hs.base64.encode(self.api_key .. ':' .. 'api_token')
    else
      return "Invalid Auth"
    end
  end

  function Toggl:_headers()
    return {
      ["Content-Type"] = "application/json",
      Authorization = "Basic " .. self:_encode_authentication()
    }
  end

  function Toggl:_get(resource)
    url = self.base_url .. '/' .. resource
    status, body, headers = hs.http.get(url, self:_headers())
    if not (status == 200) then return nil, false end
    print(self:_parse_response(body))
    return self:_parse_response(body), true
  end

  function Toggl:_parse_response(body)
    return json.decode(body)
  end

return Toggl
