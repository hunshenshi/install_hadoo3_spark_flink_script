##
args is cluster hostname, separate with a comma...
`bash install_hadoop_cluster.bash host1,host2,host3`
*The first one is master.*

## yarn web ui is master_ip:7438
## namenode web ui is master_ip:9870

## Note:
If you want install a cluster, Make sure the machines in the cluster can ssh each other.
use `ssh-keygen -t rsa`
