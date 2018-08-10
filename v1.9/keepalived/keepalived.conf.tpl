! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
}
vrrp_script chk_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    interval 2
    weight -5
    fall 3  
    rise 2
}
vrrp_instance VI_1 {
    state K8SHA_KA_STATE
    interface K8SHA_KA_INTF
    mcast_src_ip K8SHA_IPLOCAL
    virtual_router_id 51
    priority K8SHA_KA_PRIO
    advert_int 2
    authentication {
        auth_type PASS
        auth_pass K8SHA_KA_AUTH
    }
    virtual_ipaddress {
        K8SHA_IPVIRTUAL
    }
    track_script {
       chk_apiserver
    }
}
