<?php
// Start the session
session_start();
function kmb($count, $precision = 2) {
  if ($count < 1000000) {
    $n_format = number_format($count / 1000) . ' KB';
  } else if ($count < 1000000000) {
    $n_format = number_format($count / 1000000, $precision) . ' MB';
  } else {
    $n_format = number_format($count / 1000000000, $precision) . 'B';
  }
  return $n_format;
}

if(isset($_POST['add_client']))
{
  $clientName = $_POST['client'];
  shell_exec('/bin/bash /etc/openvpn/easy-rsa/create_client.sh "'.$clientName.'"');
}

if(isset($_POST['delete']))
{
  $clientName = $_POST['client'];
  shell_exec('/bin/bash /etc/openvpn/easy-rsa/delete_client.sh "'.$clientName.'"');
}

?>

<!doctype html>
<html lang="en">
<head>
  <!-- Required meta tags -->
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <!-- Bootstrap CSS -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.0-beta1/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-0evHe/X+R7YkIZDRvuzKMRqM+OrBnVFBL6DOitfPri4tjfHxaWutUpFmBp4vmVor" crossorigin="anonymous">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
  <style>
  .center {
    text-align: center
  }

  .inline {
    display: inline;
  }

  .link-button {
    background: none;
    border: none;
    color: blue;
    text-decoration: underline;
    cursor: pointer;
    font-size: 1em;
    font-family: serif;
  }
  .link-button:focus {
    outline: none;
  }
  .link-button:active {
    color:red;
  }


</style>

<title>Hello, world!</title>
</head>
<body>
  <br>

  <br>

  <div class="container-fluid">
    <div class="row">
      <div class="col-md-4 offset-md-4">
        <div class="card">
          <div class="card-header text-black bg-light">Add New Client </div>
          <div class="card-body">
            <form action='index.php' method='post' class="row g-3 needs-validation" novalidate>
              <input  class='form-control' type='text' placeholder='Client Name' name='client' required><br>
              <button type='submit' name='add_client' class='btn btn-primary btn-sm btn-block'>Add</button>
            </form>
          </div>
        </div>
      </div>
    </div>
  </div>
  <br><br>

  <div class="container-fluid">
    <div class="row">
      <div class="col-md-8 offset-md-2">
        <div class="card">
          <div class="card-header">Client List</div>
          <div class="card-body">
            <div class="table-responsive">
              <div class="center">
                <table class="table table-striped table-hover">
                  <thead class="table-dark">
                    <tr>
                      <th scope="col">Client Name</th>
                      <th scope="col">Tunnel IP</th>
                      <th scope="col">Received</th>
                      <th scope="col">Sent</th>
                      <th scope="col">Revoke</th>
                      <th scope="col">Download</th>
                      <th scope="col">Uptime</th>
                      <th scope="col">Status</th>
                      <th scope="col">Last Login</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <?php
                      $output=null;
                      $retval=null;
                      exec('cat /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d "=" -f 2', $output, $retval);
                      foreach ($output as $clientName) {
                        $server = 'server';
                        if (strcmp($clientName, $server) !== 0) {
                          echo "<th scope='row'>$clientName</th>";
                          ?>
                          <td>
                            <?php
                            $ip=shell_exec('cat /etc/openvpn/ipp.txt | grep "'.$clientName.'" | cut -d, -f 2 | tail -1');
                            if ($ip) {
                              echo $ip;
                            } else{
                              echo "0.0.0.0";
                            }

                            ?>
                          </td>
                          <td>
                            <?php
                            $bytesreceived=shell_exec('cat /etc/openvpn/openvpn-status.log | sed "s/OpenVPN CLIENT LIST//g" | grep "'.$clientName.'" | head -1 | cut -d, -f 3');
                            if ($bytesreceived){
                              $Numreturn = kmb($bytesreceived);
                              echo $Numreturn;
                            }
                            else {
                              echo "0 MB";
                            }
                            ?>

                          </td>
                          <td>

                            <?php
                            $bytessent=shell_exec('cat /etc/openvpn/openvpn-status.log | sed "s/OpenVPN CLIENT LIST//g" | grep "'.$clientName.'" | head -1 | cut -d, -f 4');
                            if ($bytessent){
                              $Numreturn = kmb($bytessent);
                              echo $Numreturn;
                            }
                            else {
                              echo "0 MB";
                            }
                            ?>

                          </td>
                          <td>
                            <form action='index.php' method='post'>
                              <input type='hidden' name='client' value='<?php echo $clientName; ?>'>
                              <button type="submit" name="delete" value="submit_value" class="link-button" Onclick="return ConfirmDelete();">
                                <i class="fa fa-trash" style="color:red;"></i>
                              </button>

                            </form>
                          </td>
                          <td>
                            <a target='_blank' href='download.sh?client=<?php echo $clientName; ?>'>
                              <span style='color:black' class='fa fa-download' aria-hidden='true'></span>
                            </a>
                          </td>
                          <td>

                            <?php
                            $active=shell_exec('cat /etc/openvpn/openvpn-status.log | sed "s/OpenVPN CLIENT LIST//g" | grep "'.$clientName.'" | head -1 | cut -d, -f 5');
                            if ($active) {
                              $tz = new DateTimeZone('UTC');
                              $now = strtotime("now");
                              $newChangeDate = strtotime($active);
                              $diff = abs($now - $newChangeDate);

                              $years = floor($diff / (365*60*60*24));

                              $months = floor(($diff - $years * 365*60*60*24)
                              / (30*60*60*24));

                              $days = floor(($diff - $years * 365*60*60*24 -
                              $months*30*60*60*24)/ (60*60*24));

                              $hours = floor(($diff - $years * 365*60*60*24
                              - $months*30*60*60*24 - $days*60*60*24)
                              / (60*60));

                              $minutes = floor(($diff - $years * 365*60*60*24
                              - $months*30*60*60*24 - $days*60*60*24
                              - $hours*60*60)/ 60);

                              $seconds = floor(($diff - $years * 365*60*60*24
                              - $months*30*60*60*24 - $days*60*60*24
                              - $hours*60*60 - $minutes*60));

                              if ($years != 0){
                                echo $years;
                                echo  " Year(s), ";
                              }

                              if ($months != 0){
                                echo $months;
                                echo "Month(s) ";
                              }

                              if ($hours != 0){
                                echo $hours;
                                echo "h ";
                              }

                              if ($minutes != 0){
                                echo $minutes;
                                echo  "Min.";
                              }
                            } else{
                              echo "Offline";
                            }
                            ?>
                          </td>
                          <td>
                            <?php
                            $ConfirmclientName=shell_exec('cat /etc/openvpn/openvpn-status.log | sed "s/ROUTING TABLE//g" | grep "'.$clientName.'" | tail -1 | cut -d , -f 2');
                            if (trim($ConfirmclientName) == trim($clientName)) {
                              echo "<span style='color:green'>Connected</span>";
                            }else {
                              echo "<span style='color:red'>Not Connected</span>";
                            }
                            ?>
                          </td>
                          <td>
                            <?php
                            $lastlogin=shell_exec('cat /etc/openvpn/client-connected.log | grep "'.$clientName.'" | tail -1 | cut -d " " -f 1-2');
                            if ($lastlogin){
                              $t = trim($lastlogin);
                              echo date("M j Y, g:i A", strtotime($t));
                            }
                            ?>
                          </td>
                        </tr>
                      <?php  }
                    } ?>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.2.0-beta1/dist/js/bootstrap.bundle.min.js" integrity="sha384-pprn3073KE6tl6bjs2QrFaJGz5/SUsLqktiwsUTF55Jfv3qYSDhgCecCxMW52nD2" crossorigin="anonymous"></script>
  <script>
  function ConfirmDelete()
  {
    return confirm("Are you sure you want to delete this client?");
  }

  (function () {
    'use strict'

    var forms = document.querySelectorAll('.needs-validation')

    Array.prototype.slice.call(forms)
    .forEach(function (form) {
      form.addEventListener('submit', function (event) {
        if (!form.checkValidity()) {
          event.preventDefault()
          event.stopPropagation()
        }

        form.classList.add('was-validated')
      }, false)
    })
  })()
  </script>

</body>
</html>
