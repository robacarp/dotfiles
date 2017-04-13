local Project = {}

function Project:new(api_response)
  local project = {
    id = nil,
    name = nil,
    at = nil,
    default_hourly_rate = nil,
    default_currency = nil,
    projects_billable_by_default = nil,
    rounding = nil,
    rounding_minutes = nil,
    api_token = nil
  }

  self.__index = self
  local object = setmetatable(project, self)
  object:fromApiResponse(api_response)

  return object
end


  function Project:fromApiResponse(api_response)
    fields = {
      "id",
      "name",
      "at",
      "default_hourly_rate",
      "default_currency",
      "projects_billable_by_default",
      "rounding",
      "rounding_minutes",
      "api_token"
    }

    print(require('downloaded_modules/inspect')(api_response))
    for i, field_name in pairs(fields) do
      self[field_name] = api_response[field_name]
    end
  end

return Project
