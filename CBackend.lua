local CBackend = {}

function CBackend:Compile(State, FileName, OutputFile, Data)
  State.CCode = "int main(){}"

  if OutputFile then
    local CFile = io.open(OutputFile, "w")
    CFile:write(State.CCode)
    CFile:close()
  end

  return State.CCode
end

return CBackend
