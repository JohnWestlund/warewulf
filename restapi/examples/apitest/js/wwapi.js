// wwapi.js
//
// Warewulf API JavaScript file
//

// Setup remove function on Arrays
if (!Array.prototype.remove) {
  Array.prototype.remove = function(val) {
    var i = this.indexOf(val);
    return i>-1 ? this.splice(i, 1) : [];
  };
}

// setupXMLHTTP
// Basic setup of XMLHTTP object for AJAX calls
function setupXMLHTTP()
{
  var xmlhttp;

  if (window.XMLHttpRequest) {
    // Should be: Chrome, Firefox, Safari, IE7+, etc...
    xmlhttp = new XMLHttpRequest();
  } else {
    // IE 5 / IE 6
    xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
  }
  xmlhttp.onreadystatechange=function()
  {
    if (xmlhttp.readyState===4) {
      if (xmlhttp.status===200) {
        console.debug("Code 200 returned");
      }
    }
  }

  xmlhttp.onload = function() {
    console.debug("Onload Success");
  }
  xmlhttp.onerror = function() {
    console.debug("onload error");
    console.debug(xmlhttp.status);
    console.debug(xmlhttp.statusText);
  }

  return xmlhttp;
}

// buildVNFS
// @id = nVnfs_sp
// Build vnfs select listing
//
// @vid VNFS ID number
function buildVNFS(vid)
{
  var xmlhttp = setupXMLHTTP();
  var rUrl = "http://" + document.domain + "/apitest/wwapi/vnfs/";
  var vnfsObj;

  xmlhttp.onreadystatechange=function()
  {
    if (xmlhttp.readyState===4) {
      if (xmlhttp.status===200) {
        console.debug("buildVNFS: Code 200 returned");

        // This will be a dump of *all* VNFS objects in the DataStore
        var sr = JSON.parse(xmlhttp.responseText);
        var vnfsObj = sr.vnfs;
        var vnfsSelect="";
        var sel="";

        vnfsSelect = "<label for='nVnfs'>VNFS: </label>\n";
        vnfsSelect += "<select name='nVnfs' id='nVnfs'>\n";

        for (var key in vnfsObj) {
          //console.log("vnfsObj[key] == " + key + "(" + vnfsObj[key].id + ")");

          if (vid === vnfsObj[key].id) {
            sel=" selected=selected";
          }
          vnfsSelect += "  <option value='" + vnfsObj[key].id + "'" + sel + ">" + vnfsObj[key].name + "</option>\n";
          sel="";
        }

        vnfsSelect += "</select>\n<br/>\n";

        document.getElementById("nVnfs_sp").innerHTML = vnfsSelect;
      }
    }
  }

  xmlhttp.open("GET", rUrl, true);
  xmlhttp.send(null);
}

// buildBootstrap
// @id = nBS_sp
// Build bootstrap select listing
//
// @vid Bootstrap ID number
function buildBootstrap(bsid)
{
  var xmlhttp = setupXMLHTTP();
  var rUrl = "http://" + document.domain + "/apitest/wwapi/bootstrap/";
  var vnfsObj;

  xmlhttp.onreadystatechange=function()
  {
    if (xmlhttp.readyState===4) {
      if (xmlhttp.status===200) {
        console.debug("buildBS: Code 200 returned");

        // This will be a dump of *all* VNFS objects in the DataStore
        var sr = JSON.parse(xmlhttp.responseText);
        var bsObj = sr.kernels;
        var bsSelect="";
        var sel="";

        bsSelect = "<label for='nBS'>Bootstrap: </label>\n";
        bsSelect += "<select name='nBS' id='nBS'>\n";

        //console.log(bsObj);
        for (var key in bsObj) {
          //console.log("bsObj[key] == " + key + "(" + bsObj[key].id + ")");

          if (bsid === bsObj[key].id) {
            sel=" selected=selected";
          }
          bsSelect += "  <option value='" + bsObj[key].id + "'" + sel + ">" + bsObj[key].name + "</option>\n";
          sel="";
        }

        bsSelect += "</select>\n<br/>\n";

        document.getElementById("nBS_sp").innerHTML = bsSelect;
      }
    }
  }

  xmlhttp.open("GET", rUrl, true);
  xmlhttp.send(null);
}

// getVNFSById
// @id = nVnfs
//
// @vid VNFS Id
function getVNFSById(vid)
{
  var xmlhttp = setupXMLHTTP();
  var rUrl = "http://" + document.domain + "/apitest/wwapi/vnfs/" + vid;
  var vnfsObj;

  xmlhttp.onreadystatechange=function()
  {
    if (xmlhttp.readyState===4) {
      if (xmlhttp.status===200) {
        console.debug("getVNFSByID: Code 200 returned");

        // So, we use sr.vnfs[vid] to get the object. Thanks Matt! - JMS
        var sr = JSON.parse(xmlhttp.responseText);
        var vnfsObj = sr.vnfs[vid];
        console.debug("vnfsObj value");
        console.debug(vnfsObj);

        document.getElementById("nVnfs").value = vnfsObj.name;
      }
    }
  }

  xmlhttp.open("GET", rUrl, true);
  xmlhttp.send(null);
}

// buildFiles
// @id = nFile_sp
// Build file checkbox form
//
// @farr File Array from nodeObj.fileids
function buildFiles(farr)
{
  var xmlhttp = setupXMLHTTP();
  var rUrl = "http://" + document.domain + "/apitest/wwapi/file/";
  var fileObj;

  xmlhttp.onreadystatechange=function()
  {
    if (xmlhttp.readyState===4) {
      if (xmlhttp.status===200) {
        console.debug("buildFiles: Code 200 returned");

        // This will be a dump of *all* VNFS objects in the DataStore
        var sr = JSON.parse(xmlhttp.responseText);
        var fileObj = sr.files;
        var fileSelect="";
        var sel="";

        //console.debug("fileObj value");
        //console.debug(fileObj);
        console.debug(farr);

        fileSelect = "\n";

        for (var key in fileObj) {
          //console.log("fileObj[key] == " + key + "(" + fileObj[key]._id + ")");

          for (var i in farr) {
            if (farr[i] === fileObj[key]._id) {
              sel=" checked='checked'";
              // Remove matched element from Array
              farr.remove(farr[i]);
            }
          }
          fileSelect += "<input id='f_" + fileObj[key]._id + "' name='fileids' type='checkbox' value='" + fileObj[key]._id + "'" + sel + ">" + fileObj[key].name + "</input><br/>\n";
          sel="";
        }

        fileSelect += "<br/>\n";

        document.getElementById("nFile_sp").innerHTML = fileSelect;
      }
    }
  }

  xmlhttp.open("GET", rUrl, true);
  xmlhttp.send(null);
}

// buildNodeNetDev
// @id = nNetDev_sp
//
// @nodeObj Node Object
function buildNodeNetdev(nodeObj)
{
  var ndev = nodeObj.netdevs;
  console.debug(ndev);
  var ndev_html = "<div id='netdevs'>\n";

  ndev_html += "<span>Name | IPAddr | Netmask | Gateway | HWAddr</span><br/>\n";
  for (var keys in ndev) {
    //console.log("ndevs[key].name == " + ndev[keys].name);
    //console.log("ndevs[key].ipaddr == " + ndev[keys].ipaddr);
    ndev_name = ndev[keys].name;
    ndev_ipaddr = ndev[keys].ipaddr;
    ndev_netmask = ndev[keys].netmask;
    ndev_gateway = ndev[keys].gateway;
    ndev_hwaddr = ndev[keys].hwaddr;

    //console.log(ndev_name + " " + ndev_ipaddr + " " + ndev_netmask + " " + ndev_gateway + " " + ndev_hwaddr);
    ndev_html += "<input type='text' id='ndev_" + ndev_name + "' readonly=readonly size='5' value='" + ndev_name + "' />";
    ndev_html += "<input type='text' id='ndev_" + ndev_ipaddr + "' readonly=readonly size='15' maxLength='15' value='" + ndev_ipaddr + "' />";
    if (ndev_netmask != undefined) {
      ndev_html += "<input type='text' id='ndev_" + ndev_netmask + "' readonly=readonly size='15' maxLength='15' value='" + ndev_netmask + "' />";
    }
    if (ndev_gateway != undefined) {
      ndev_html += "<input type='text' id='ndev_" + ndev_gateway + "' readonly=readonly size='15' maxLength='15' value='" + ndev_gateway + "' />";
    }
    if (ndev_hwaddr != undefined) {
      ndev_html += "<input type='text' id='ndev_" + ndev_hwaddr + "' readonly=readonly size='18' maxLength='17' value='" + ndev_hwaddr + "' />";
    }

    ndev_html += "<br/>\n";
  }

  ndev_html += "</div>\n";
  document.getElementById("nNetDev_sp").innerHTML = ndev_html;
}

function getNode()
{
  var nid = document.getElementById("nlookup").value;

  if (nid.length == 0) {
    return;
  }
  document.getElementById("warntxt").innerHTML = "";

  var xmlhttp = setupXMLHTTP();
  var rUrl = "http://" + document.domain + "/apitest/wwapi/node/" + nid;

  // This connection is done as sync. It must complete, or fail, to continue.
  xmlhttp.open("GET", rUrl, false);
  xmlhttp.send(null);

  var nodeObj;
  if (xmlhttp.status === 200) {
    var sr = JSON.parse(xmlhttp.responseText);
    console.debug("sr object");
    console.debug(sr);
    nodeObj = sr.node[nid];
    console.debug("Node object");
    console.debug(nodeObj);
  } else if (xmlhttp.status === 404) {
    document.getElementById("warntxt").innerHTML = "<b>Error:</b> Node not found";
    return;
  } else {
    console.debug("xmlhttp status NOT 200");
    console.debug("Status returned: " + xmlhttp.status);
    return;
  }

  // Start building out form
  document.getElementById("nName").value = nodeObj.nodename;
  document.getElementById("nHwaddr").value = nodeObj._hwaddr;
  //getVNFSById(nodeObj.vnfsid);
  buildVNFS(nodeObj.vnfsid);
  buildBootstrap(nodeObj.bootstrapid);
  buildFiles(nodeObj.fileids);
  buildNodeNetdev(nodeObj);
}

//vim: filetype=javascript:syntax=javascript:expandtab:ts=2:sw=2:
