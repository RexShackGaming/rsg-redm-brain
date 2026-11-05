---
title: REVIEW — Files
---

# Files <Badge type="tip" text="Server Side Only" />
## Open


Open a file from a given file path
|Parameter| Description|
|--|--|
| resourcename | the string name of your resource |
| filepath | the path to the file you with to open or create |

`FeatherCore.Files:Open(resourcename, filepath))` 
  
Example Usage:
```lua



CreateThread(function()
    local file = FeatherCore.Files:Open(GetCurrentResourceName(), 'data.txt')
end)
```

## Read


Read the file that you have openned.

|Parameter| Description|
|--|--|
| mode | if nothing, it will default to standard read, mode are 'standard' or 'table'. Table will store a table to the file properly |

`file:Read(mode)` 
  
Example Usage:
```lua




CreateThread(function()
    local file = FeatherCore.Files:Open(GetCurrentResourceName(), 'data.txt')
    local filedata = file:Read()
end)
```

## Save


Save data to the file that you have opened.

|Parameter| Description|
|--|--|
| content | The data you with to save to the file |
| mode | if nothing, it will default to standard save, modes are 'standard' or 'table'. Table will store a table to the file properly |

`file:Save(content, mode)` 
  
Example Usage:
```lua




CreateThread(function()
    local file = FeatherCore.Files:Open(GetCurrentResourceName(), 'data.txt')
    local filedata = file:Read()

    local data = "Some Awesome stuff!"

    file:Save(data)
end)
```

## Update


Instead of needing to open and save a file, you can update data directly to the file.

|Parameter| Description|
|--|--|
| content | The data you with to save to the file |
| mode | if nothing, it will default to standard save, modes are 'standard' or 'table'. Table will store a table to the file properly |

`file:Update(content, mode)` 
  
Example Usage:
```lua




CreateThread(function()
    local file = FeatherCore.Files:Open(GetCurrentResourceName(), 'data.txt')
    file:Update("Some Awesome stuff!")
end)
```

## Lazy Functions


There is a way to use these functions without needing to call the Open() function, this can be used for quick usage or prototyping, but is non-optimal and slower than the above. 

### Load File


Read the file that you have openned.

|Parameter| Description|
|--|--|
| resourcename | Name of the resource |
| filepath | path to the file you with to load |
| mode | if nothing, it will default to standard read, mode are 'standard' or 'table'. Table will store a table to the file properly |

`FeatherCore.Files:Load(resourcename, filepath, mode)` 
  
Example Usage:
```lua



-- Lazy functions, not as optimized
CreateThread(function()
    local file = FeatherCore.Files:Load(GetCurrentResourceName(), 'data.txt')
end)
```

### Save File


Save the file that you have openned.

|Parameter| Description|
|--|--|
| resourcename | Name of the resource |
| filepath | path to the file you with to load |
| content | data to save to the file |
| mode | if nothing, it will default to standard read, mode are 'standard' or 'table'. Table will store a table to the file properly |

`FeatherCore.Files:Load(resourcename, filepath, mode)` 
  
Example Usage:
```lua



-- Lazy functions, not as optimized
CreateThread(function()
    FeatherCore.Files:Save(GetCurrentResourceName(), 'data.txt', "Some cool stuff!")
end)
```

### Update File


Update the file that you have openned.

|Parameter| Description|
|--|--|
| resourcename | Name of the resource |
| filepath | path to the file you with to load |
| content | data to update to the file |
| mode | if nothing, it will default to standard read, mode are 'standard' or 'table'. Table will store a table to the file properly |

`FeatherCore.Files:Update(resourcename, filepath, content, mode)` 
  
Example Usage:
```lua



-- Lazy functions, not as optimized
CreateThread(function()
    FeatherCore.Files:Update(GetCurrentResourceName(), 'data.txt', "Some cool stuff!")
end)
```
