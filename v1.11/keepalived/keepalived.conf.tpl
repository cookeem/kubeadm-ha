! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
}
vrrp_script check_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    interval 5
    weight -60
    fall 2
    rise 2
}
vrrp_instance VI_1 {
    state K8SHA_KA_STATE
    interface K8SHA_KA_INTF
    mcast_src_ip K8SHA_IPLOCAL
    virtual_router_id 51
    priority K8SHA_KA_PRIO
    advert_int 5
    authentication {
        auth_type PASS
        auth_pass K8SHA_KA_AUTH
    }
    virtual_ipaddress {
        K8SHA_VIP
    }
    track_script {
       check_apiserver
    }
}
