local ffi = require("ffi")

ffi.cdef[[
    typedef int pid_t;
    int pipe(int fildes[2]);
    pid_t fork(void);
    ssize_t write(int fd, const void *buf, size_t count);
    ssize_t read(int fd, void *buf, size_t count);
    int close(int fd);
    int waitpid(pid_t pid, int *status, int options);
    int dup2(int oldfd, int newfd);
    int execvp(const char *file, char *const argv[]);
]]

local luapiper = {}

function luapiper.Pipe()
    local pipe_fd = ffi.new("int[2]")
    if ffi.C.pipe(pipe_fd) == -1 then
        error("couldn't create a pipe")
    end

    local closePipe = function()
        ffi.C.close(pipe_fd[0])
        ffi.C.close(pipe_fd[1])
    end

    return pipe_fd, closePipe
end

function luapiper.PipeSession(program, args)
    local child = {}
    local pipe_fd, closePipe = luapiper.Pipe()

    child.id = ffi.C.fork()
    child.pipe = pipe_fd

    if child.id == -1 then
        error("could not create child process")
    elseif child.id == 0 then
        -- Child process code
        ffi.C.close(child.pipe[1])  -- Close the write end of the pipe in the child process

        -- Redirect STDIN to the read end of the pipe
        ffi.C.dup2(child.pipe[0], 0)
        ffi.C.close(child.pipe[0])

        -- Convert Lua table of arguments to a C array
        local argv = ffi.new("char *[?]", #args + 2)
        argv[0] = ffi.new("char[?]", #program + 1)
        ffi.copy(argv[0], program)
        for i, arg in ipairs(args) do
            argv[i] = ffi.new("char[?]", #arg + 1)
            ffi.copy(argv[i], arg)
        end
        argv[#args + 1] = nil  -- Null-terminate the array

        -- Execute the specified program with arguments
        ffi.C.execvp(program, argv)

        -- If execvp fails
        error("execvp failed")
    else
        -- Parent process code
        ffi.C.close(child.pipe[0])  -- Close the read end of the pipe in the parent process
        child.close = function()
            closePipe()
            ffi.C.waitpid(child.id, nil, 0)
        end

        child.send = function(child, message)
            print("Sending message:", message)
            local msg_ptr = ffi.cast("const void*", message)  -- Convert string to pointer
            ffi.C.write(child.pipe[1], msg_ptr, #message + 1)
        end

        return child
    end
end

local function example()
    local program = "pixilang"
    local args = { "./src/entrypoint.pixi" }

    local child = luapiper.PipeSession(program, args)

    while true do
        --local command = io.read()

        child:send("clear #WHITE;frame 0")
    end

    child:close()
end

-- Uncomment the line below to run the example
--example()

return luapiper

