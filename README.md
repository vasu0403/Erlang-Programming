# Distributed Systems Assignment 2
---
## Erlang Programming
### Instructions
To run the code:
```
erlc <file>.erl
erl -noshell -s <file> main <input file> <output file> -s init stop
```
### Problem 1 (*Token Ring*)
- **Description**:
The root process spawns P processes and sends the token to process 0. Process 0 sends the token to prcess 1, process 1 sends the token to process 2; process *p* sends the token to process *(p + 1) % P*
- **Analysis**:
For P processes, the time complexity is O\(P\) messages.
### Problem 2 (*Single source shortest path*)
- **Description**:
Implemented a distributed version of Bellman-Ford algorithm. Each process is given a set of edges. Each process does the relaxation of distances but only considering the edges allocated to him. Since the distance array is not shared among the processes, after each iteration each process sends his distance array to every other process. This process continues until no further relaxations take place in a particular iteration (This would at max take around |V| - 1 iterations)
- **Analysis**:
    - Time complexity - O\(VE/P\) + Message Passing (In each iteration P*P messages are passed).
    - For a dense graph with 100 vertices, the algorithm takes around 2 seconds to complete.
 