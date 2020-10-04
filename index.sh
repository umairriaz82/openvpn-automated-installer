#!/bin/bash
#The admin interface for OpenVPN

echo "Content-type: text/html"
echo ""
echo "<!doctype html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, shrink-to-fit=no\">
<meta name=\"description\" content=\" A simple OpenVPN server with a web-based admin panel..\">
<meta name=\"author\" content=\"Umair Riaz\">
<title>OpenVPN Serve Admin UI</title>

<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css\">
<link rel=\"stylesheet\" href=\"https://use.fontawesome.com/releases/v5.6.3/css/all.css\" integrity=\"sha384-UHRtZLI+pbxtHCWp1t77Bi1L4ZtiqrqD80Kn4Z8NTSRyMA2Fd33n5dQ8lWUE00s/\" crossorigin=\"anonymous\"></head>
<script src=\"https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js\"></script>
<script src=\"https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.16.0/umd/popper.min.js\"></script>
<script src=\"https://maxcdn.bootstrapcdn.com/bootstrap/4.3.1/js/bootstrap.min.js\"></script>
<meta name=\"theme-color\" content=\"#563d7c\">


<style>
td.list{
  padding:4px !important;
  text-align: center;
  vertical-align: middle !important;
}
th.list {
  padding: 10px;
  color: #626567;
  text-align: center;
}
body {
  padding-top:100px;
}
.bd-placeholder-img {
  font-size: 1.125rem;
  text-anchor: middle;
  -webkit-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
  user-select: none;
}
@media (min-width: 768px) {
  .bd-placeholder-img-lg {
    font-size: 3.5rem;
  }
}
</style>
<!-- Custom styles for this template -->
</head>


<body>


<nav class=\"navbar navbar-expand-md navbar-dark bg-dark fixed-top\">
<a class=\"navbar-brand\" href=\"#\">OpenVPN Server Administration UI</a>
<button class=\"navbar-toggler\" type=\"button\" data-toggle=\"collapse\" data-target=\"#navbarsExampleDefault\" aria-controls=\"navbarsExampleDefault\" aria-expanded=\"false\" aria-label=\"Toggle navigation\">
<span class=\"navbar-toggler-icon\"></span>
</button>

<div class=\"collapse navbar-collapse\" id=\"navbarsExampleDefault\">
<ul class=\"navbar-nav mr-auto\">
</ul>
<ul class=\"nav navbar-nav navbar-right\">
<i style='color:white' class=\"fas fa-cog\"></i>&nbsp
<a href='index.sh?option=reboot'><i style='color:white' class=\"fas fa-sync\"></i>&nbsp</a>
<a href='index.sh?option=shutdown'><i style='color:white' class=\"fas fa-power-off\"></i>&nbsp</a>
</ul>
</div>
</nav>



<div class=\"container-fluid\">
    <div class=\"row\">
        <div class=\"col-md-4 offset-md-4\">
            <div class=\"card\">
            <div class=\"card-header\">Add New Client </div>
            <div class=\"card-body\">
            <form action='index.sh' method='get'>
            <input type='hidden' name='option' value='add'>
           <div class='form-group'><input  class='form-control' type='text' placeholder='Client Name' name='client'></div> <button type='submit' class='btn btn-primary btn-sm btn-block'>Add</button>
            </form>
            </div>
            </div>
        </div>
    </div>
</div>
<br>
<div class=\"container-fluid\">
    <div class=\"row\">
        <div class=\"col-md-8 offset-md-2\">
            <div class=\"card\">"

            eval `echo "${QUERY_STRING}"|tr '&' ';'`

            IP=$(wget -4qO- "http://whatismyip.akamai.com/")

            newclient () {
            	# Generates the custom client.ovpn
            	cp /etc/openvpn/client-common.txt /etc/openvpn/clients/$1.ovpn
            	echo "<ca>" >> /etc/openvpn/clients/$1.ovpn
            	cat /etc/openvpn/easy-rsa/pki/ca.crt >> /etc/openvpn/clients/$1.ovpn
            	echo "</ca>" >> /etc/openvpn/clients/$1.ovpn
            	echo "<cert>" >> /etc/openvpn/clients/$1.ovpn
            	cat /etc/openvpn/easy-rsa/pki/issued/$1.crt >> /etc/openvpn/clients/$1.ovpn
            	echo "</cert>" >> /etc/openvpn/clients/$1.ovpn
            	echo "<key>" >> /etc/openvpn/clients/$1.ovpn
            	cat /etc/openvpn/easy-rsa/pki/private/$1.key >> /etc/openvpn/clients/$1.ovpn
            	echo "</key>" >> /etc/openvpn/clients/$1.ovpn
            	echo "<tls-auth>" >> /etc/openvpn/clients/$1.ovpn
            	cat /etc/openvpn/ta.key >> /etc/openvpn/clients/$1.ovpn
            	echo "</tls-auth>" >> /etc/openvpn/clients/$1.ovpn
            }

            cd /etc/openvpn/easy-rsa/

            case $option in
            	"add") #Add a client
            		./easyrsa build-client-full $client nopass
            		# Generates the custom client.ovpn
            		newclient "$client"
                echo "<div class=\"alert alert-success\" role=\"alert\">New Client <span style='color:red'>$client</span> added.</div>"
            	;;
            	"revoke") #Revoke a client
            		echo "<span style='display:none'>"
            		./easyrsa --batch revoke $client
            		./easyrsa gen-crl
            		echo "</span>"
            		rm -rf pki/reqs/$client.req
            		rm -rf pki/private/$client.key
            		rm -rf pki/issued/$client.crt
            		rm -rf /etc/openvpn/crl.pem
                rm /etc/openvpn/clients/$client.ovpn
            		cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
            		# CRL is read with each client connection, when OpenVPN is dropped to nobody
            		echo "<div class=\"alert alert-success\" role=\"alert\">Client <span style='color:red'>$client</span> deleted.</div>"
            	;;
              "reboot")
                echo "reboooting"
                systemctl restart openvpn@server
              ;;
              "shutdown")
                echo "shutdown"
                cd /etc/init.d/
                pwd
                systemctl status openvpn@server
                echo "<br>"
                echo "<br>"
                /etc/init.d/openvpn stop
                echo "<br>"
                /etc/init.d/openvpn status
              ;;
            esac

            NUMBEROFCLIENTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
            if [[ "$NUMBEROFCLIENTS" = '0' ]]; then
            	echo "<div class=\"card\">
  <div class=\"card-body\">
    <center>Client List is empty. </center>
  </div>
</div>"
            else
                echo "<div class=\"card-header\">Client List</div>
                <div class=\"card-body\">
                    <div class=\"table-responsive\">
                        <table class=\"table table-striped table-hover\">
                            <thead>
                                <tr>
                                    <th class=\"list\">Client Name</th>
                                    <th class=\"list\">Tunnel IP</th>
                                    <th class=\"list\">Received</th>
                                    <th class=\"list\">Sent</th>
                                    <th class=\"list\">Uptime</th>
                                    <th class=\"list\">Revoke</th>
                                    <th class=\"list\">Download</th>
                                    <th class=\"list\">Status</th>
                                    <th class=\"list\">Last Login</th>
                                </tr>
                            </thead>
                            <tbody>"

                          	while read c; do
                          		if [[ $(echo $c | grep -c "^V") = '1' ]]; then
                          			clientName=$(echo $c | cut -d '=' -f 2)

                          			if [[ "$clientName" != "server" ]] ; then
                          				echo "<tr><td class=\"list\">$clientName</td>"
                                  echo "<td class=\"list\">"
                                  ip=$(cat /etc/openvpn/ipp.txt | grep -w $clientName | cut -d, -f 2)

                                  if [ -z "$ip" ]
                                    then
                                      echo "0.0.0.0"
                                    else
                                      echo $ip
                                    fi
                                  echo "</td>"

                                  echo "<td class=\"list\">"
                                  bytesreceived=$(cat /etc/openvpn/openvpn-status.log | sed "s/OpenVPN CLIENT LIST//g" | grep $clientName | head -1 | cut -d, -f 3)
                                  if [ -z "$bytesreceived" ]
                                    then
                                      echo "0 Bytes"
                                    else

                                    printf %.2f $(echo "$bytesreceived*0.000001" | bc -l); echo " MB"
                                    fi
                                  echo "</td>"

                                  echo "<td class=\"list\">"
                                  bytessent=$(cat /etc/openvpn/openvpn-status.log | sed "s/OpenVPN CLIENT LIST//g" | grep $clientName | head -1 | cut -d, -f 4)
                                  if [ -z "$bytessent" ]
                                    then
                                      echo "0 Bytes"
                                    else
                                      printf %.2f $(echo "$bytessent*0.000001" | bc -l); echo " MB"
                                    fi
                                  echo "</td>"

                                  echo "<td class=\"list\">"
                                  active=$(cat /etc/openvpn/openvpn-status.log | sed "s/OpenVPN CLIENT LIST//g" | grep $clientName | head -1 | cut -d, -f 5)
                                  if [ -z "$active" ]
                                    then
                                      echo "Offline"
                                    else


                                      testDate=$(date '+%c')

                                      D1=$(date -d "$active" '+%s')
                                      D2=$(date -d "$testDate" '+%s')
                                      day=$(((D2-D1)/86400))

                                      hour=$( (date -u -d@$((D2-D1)) '+%k') )
                                      newhour=$(((hour-0)/1))


                                      if [[ "$day" == 0 ]];
                                      then
                                          if [[ "$newhour" == 0 ]];
                                          then
                                            echo "$(date -u -d@$((D2-D1)) +%M)"; echo " Minute(s)"
                                          else
                                            echo "$(date -u -d@$((D2-D1)) +"%kh %M min.")"
                                          fi
                                        else
                                          echo $day"d";echo "$(date -u -d@$((D2-D1)) +'%kh %M'min)"
                                      fi
                                    fi
                                  echo "</td>"


                          				echo "<td class=\"list\"><a href='index.sh?option=revoke&client=$clientName'><span style='color:red' class='fa fa-trash' aria-hidden='true'></span></a></td>"
                          				echo "<td class=\"list\"><a target='_blank' href='download.sh?client=$clientName'><span style='color:black' class='fa fa-download' aria-hidden='true'></span></a></td>"
                                  echo "<td class=\"list\">"
                                    ConfirmclientName=$(cat /etc/openvpn/openvpn-status.log | sed "s/ROUTING TABLE//g" | grep $clientName | tail -1 | cut -d , -f 2)
                                    if [[ "$clientName" == "$ConfirmclientName" ]] ; then
                                      echo "<span style='color:green'>Connected</span>"
                                    else
                                      echo "<span style='color:red'>Not Connected</span>"
                                    fi
                                  "</td>"
                                  lastlogin=$(cat /etc/openvpn/client-connected.log | grep $clientName | tail -1 | cut -d " " -f 1-2)
                                  echo "<td class=\"list\">$lastlogin</td>
                                  </tr>"

                          			fi
                          		fi
                          	done </etc/openvpn/easy-rsa/pki/index.txt


                            "</tbody>
                        </table>
                    </div>
                </div>"
              fi
              "
            </div>
        </div>
    </div>

</div>



</body>
</html>"
exit 0

