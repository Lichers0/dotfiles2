local M = {}

-- Get tags file path
function M.get_tags_file()
  local storage = require("terminal-history.storage")
  return storage.get_storage_dir() .. "/user_tags.json"
end

-- Load all tags
function M.load_tags()
  local storage = require("terminal-history.storage")
  return storage.read_json(M.get_tags_file()) or {}
end

-- Save tags
function M.save_tags(tags)
  local storage = require("terminal-history.storage")
  return storage.write_json(M.get_tags_file(), tags)
end

-- Add tag to item
function M.add_tag(item_id, tag)
  local tags = M.load_tags()
  
  if not tags[item_id] then
    tags[item_id] = {}
  end
  
  -- Check if tag already exists
  for _, existing_tag in ipairs(tags[item_id]) do
    if existing_tag == tag then
      return false -- Tag already exists
    end
  end
  
  table.insert(tags[item_id], tag)
  M.save_tags(tags)
  return true
end

-- Remove tag from item
function M.remove_tag(item_id, tag)
  local tags = M.load_tags()
  
  if not tags[item_id] then
    return false
  end
  
  for i, existing_tag in ipairs(tags[item_id]) do
    if existing_tag == tag then
      table.remove(tags[item_id], i)
      if #tags[item_id] == 0 then
        tags[item_id] = nil
      end
      M.save_tags(tags)
      return true
    end
  end
  
  return false
end

-- Get tags for item
function M.get_item_tags(item_id)
  local tags = M.load_tags()
  return tags[item_id] or {}
end

-- Get all items with specific tag
function M.get_items_by_tag(tag)
  local tags = M.load_tags()
  local items = {}
  
  for item_id, item_tags in pairs(tags) do
    for _, item_tag in ipairs(item_tags) do
      if item_tag == tag then
        table.insert(items, item_id)
        break
      end
    end
  end
  
  return items
end

-- Get all unique tags
function M.get_all_tags()
  local tags = M.load_tags()
  local unique_tags = {}
  
  for _, item_tags in pairs(tags) do
    for _, tag in ipairs(item_tags) do
      unique_tags[tag] = true
    end
  end
  
  local result = {}
  for tag, _ in pairs(unique_tags) do
    table.insert(result, tag)
  end
  
  table.sort(result)
  return result
end

-- Search items by tags (supports multiple tags with AND/OR logic)
function M.search_by_tags(search_tags, logic)
  logic = logic or "OR" -- Default to OR logic
  local tags = M.load_tags()
  local results = {}
  
  for item_id, item_tags in pairs(tags) do
    local match = false
    
    if logic == "AND" then
      -- Item must have ALL search tags
      match = true
      for _, search_tag in ipairs(search_tags) do
        local has_tag = false
        for _, item_tag in ipairs(item_tags) do
          if item_tag == search_tag then
            has_tag = true
            break
          end
        end
        if not has_tag then
          match = false
          break
        end
      end
    else -- OR logic
      -- Item must have AT LEAST ONE search tag
      for _, search_tag in ipairs(search_tags) do
        for _, item_tag in ipairs(item_tags) do
          if item_tag == search_tag then
            match = true
            break
          end
        end
        if match then
          break
        end
      end
    end
    
    if match then
      results[item_id] = item_tags
    end
  end
  
  return results
end

return M