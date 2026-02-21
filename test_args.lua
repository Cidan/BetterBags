local function fn(...)
    print("Args:", select("#", ...))
    for i=1, select("#", ...) do
        print(i, (select(i, ...)))
    end
    print("Select 2:", select(2, ...))
end
fn("event", "ctx", "arg1", "arg2")
