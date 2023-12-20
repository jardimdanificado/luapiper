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

local function createPipe()
    local pipe_fd = ffi.new("int[2]")
    if ffi.C.pipe(pipe_fd) == -1 then
        error("Erro ao criar a pipe")
    end
    return pipe_fd
end

local function createChildProcess(pipe_fd)
    local pid = ffi.C.fork()

    if pid == -1 then
        error("Erro ao criar o processo filho")
    elseif pid == 0 then
        -- Código do processo filho
        ffi.C.close(pipe_fd[1])  -- Fechar a extremidade de escrita da pipe no processo filho

        while true do
            local buffer_size = 1024
            local buffer = ffi.new("char[?]", buffer_size)
            local bytes_read = ffi.C.read(pipe_fd[0], buffer, buffer_size)

            if bytes_read <= 0 then
                break
            end

            local command = ffi.string(buffer, bytes_read)
            print("Processo filho executando:", command)
            os.execute(command)
        end

        ffi.C.close(pipe_fd[0])  -- Fechar a extremidade de leitura da pipe no processo filho
        os.exit(0)
    else
        -- Código do processo pai
        ffi.C.close(pipe_fd[0])  -- Fechar a extremidade de leitura da pipe no processo pai
        return pid
    end
end

local function main()
    local pipe_fd = createPipe()
    local child_pid = createChildProcess(pipe_fd)

    while true do
        io.write("Digite o comando (ou 'exit' para sair): ")
        local command = io.read()

        if command == "exit" then
            break
        end

        ffi.C.write(pipe_fd[1], command, #command + 1)
    end

    ffi.C.close(pipe_fd[1])  -- Fechar a extremidade de escrita da pipe no processo pai
    ffi.C.waitpid(child_pid, nil, 0)
end

main()

