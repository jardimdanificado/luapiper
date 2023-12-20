local ffi = require("ffi")

ffi.cdef[[
    typedef int pid_t;
    int pipe(int fildes[2]);
    pid_t fork(void);
    ssize_t write(int fd, const void *buf, size_t count);
    ssize_t read(int fd, void *buf, size_t count);
    int close(int fd);
    int waitpid(pid_t pid, int *status, int options);
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

function luapiper.PipeSession()
    local child = {}
    local pipe_fd, closePipe = luapiper.Pipe()

    child.id = ffi.C.fork()
    child.pipe = pipe_fd

    if child.id == -1 then
        error("could not create child process")
    elseif child.id == 0 then
        -- Child process code
        ffi.C.close(child.pipe[1])  -- Close the write end of the pipe in the child process

        while true do
            local buffer_size = 1024
            local buffer = ffi.new("char[?]", buffer_size)
            local bytes_read = ffi.C.read(child.pipe[0], buffer, buffer_size)

            if bytes_read <= 0 then
                break
            end

            local command = ffi.string(buffer, bytes_read)
            os.execute(command)
        end

        ffi.C.close(child.pipe[0])  -- Close the read end of the pipe in the child process
        os.exit(0)
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
    local child = luapiper.PipeSession()

    while true do
        --io.write("shell> ")
        local command = io.read()

        if command == "exit" then
            break
        end

        child:send(command)
    end

    child:close()
end

--example()

return luapiper;
