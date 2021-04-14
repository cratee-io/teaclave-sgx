# hello-world

## Quickstart

```bash
cmake -B build
cd build
make run
```

Successful output should be similar to

```bash
[+] Init Enclave Successful 210565066653698!
This is a normal world string passed into Enclave!
This is a in-Enclave Rust string!
[+] say_something success...
ecall_say_hello_to...
hello from ocall, sammyne
done ecall_say_hello_to
[+] ecall_say_hello_to success...
[100%] Built target run
```
