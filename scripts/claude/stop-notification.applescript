on run argv
    -- Get the input from arguments
    if (count of argv) > 0 then
        set inputText to item 1 of argv
    else
        set inputText to "No message provided"
    end if
    
    -- Display system notification
    display notification inputText with title "Claude task finished"
end run
