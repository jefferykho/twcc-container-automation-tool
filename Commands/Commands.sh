# @containername1       # <-- (Optional) Define a specific container name
# run GPU for 20 seconds
./gpu_burn 20
# run GPU for 20 seconds
./gpu_burn 20
# No name set for this block (will use default/timestamp)
# run GPU for 20 seconds
./gpu_burn 20
# run GPU for 20 seconds
./gpu_burn 20
# @containername3
./gpu_burn 20
./gpu_burn 20


# @containername4
./gpu_burn 10
./gpu_burn 10
./gpu_burn 10
./gpu_burn 20
END                     # <-- (Mandatory) Signals the script to stop parsing
