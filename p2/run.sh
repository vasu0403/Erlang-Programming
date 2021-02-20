#!/bin/bash

# while :
# do
    ./make_test
    erl -noshell -s 2018101087_2 main in.txt out.txt -s init stop
    ./checker
# done;