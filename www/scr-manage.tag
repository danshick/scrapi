<group-list>

  <form class="login" if="{ auth.loggedIn == 'no' }" onsubmit={ processLogin } >
    <input type="text" id="username" placeholder="Username"></input><br/>
    <input type="password" id="password" placeholder="Password"></input>
    <input type="submit" value="Log In"></input>
  </form>
  
  <div if="{ auth.loggedIn == 'yes' }">
    <input type="button" id="logout" value="Logout" onclick={ processLogout }></input>
    <ul>
      <li each="{ g, gobj in groups.list }" >
        <h3>{ g }</h3>
        <ul>
          <li each="{ f, fobj in gobj }" >
            { f } - <a href="../../scrapi/group/{ g }/{ f }" >{ fobj.name + '.' + fobj.ext }</a> - SHA1: { fobj.sha1 }
          </li>
          <li>
            <div class="drop_zone" id="drop_zone_{ g }" data-group="{ g }" ondrop={ parent.drop_file } ondragover={ parent.drag_file }>
              <div if="{ parent.dropbox.hasOwnProperty(g) }">
                <input type="text" id="fileTitle-{ g }" placeholder="Enter document title"></input><br/>
                Filename: { parent.dropbox[g].name } - 
                Type: { parent.dropbox[g].type } - 
                Size: { parent.dropbox[g].size } - 
                Last Modified Date: { parent.dropbox[g].lastModified } <br/><br/>
                <input type="button" id="file_{ g }" data-group="{ g }" value="Upload!" onclick={ parent.upload }></input>
              </div>
              
              <div if="{ !(parent.dropbox.hasOwnProperty(g)) }">
                "Drop files here"
              </div>
              
            </div>
          </li>
        </ul>
      </li>
    </ul>
  </div>
  <script>
    var tag = this;
    
    function Auth(){
      
      var thisL = this;
      riot.observable(this);
      this.loggedIn = "unsure";

      if(!(localStorage.getItem("auth-token") === null)){
        var client = new XMLHttpRequest();
        client.open("get", "../../scrapi/checkToken", true);
        client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
        client.send();
        client.onreadystatechange = function(){
          if ( client.readyState == 4 ){
            if( client.status == 200 ){
              thisL.loggedIn = "yes";
              tag.update();
            }
            else{
              thisL.loggedIn = "no";
              tag.update();
            }
          }
        }
      }
      else{
        thisL.loggedIn = "no";
        tag.update();
      }
      
      this.on('getToken', function(){
        
        var user = document.getElementById("username").value;
        var pass = document.getElementById("password").value;
        var client = new XMLHttpRequest();
        client.open("post", "../../scrapi/login", true);
        client.send(JSON.stringify({username:user, password:pass}));
        
        client.onreadystatechange = function(){
          if ( client.readyState == 4 ){
            if ( client.status == 200 ){
              var res = JSON.parse(client.response);
              var tomorrow = new Date(Date.now() + 24*60*60 );
              localStorage.setItem("auth-token", res["auth-token"] );
              this.cookie="Authorization="+ res["auth-token"] +"; expires="+tomorrow.toUTCString()+"; path=/scrapi";
              document.cookie = this.cookie;
              thisL.loggedIn = "yes";
              console.log(this.cookie);
              tag.update();
            }
            else if( client.status == 403 ){
              
              humane.log("Login incorrect.", { timeout: 4000, clickToClose: true })
              
            }
              
          }
        }
      });
    }
    this.auth = new Auth();
    
    this.groups = new Groups();
    this.groups.trigger('update');
    
    function Groups(){
      riot.observable(this);
      var thisG = this;
      this.list = {};
      this.files = new Files();
      
      this.on('update', function(){
        var client = new XMLHttpRequest();
        client.open("get", "../../scrapi/group", true);
        client.send();
        
        client.onreadystatechange = function(){
          if (client.readyState == 4 && client.status == 200){
            var res = JSON.parse(client.response);
            for( var g in res ){
              thisG.list[res[g]] = {};
              thisG.files.trigger('update', res[g]);
            }
          }
        }
      });
      
      function Files(g){
        riot.observable(this);
        
        this.on('update', function(g){
          var client = new XMLHttpRequest();
          client.open("get", "../../scrapi/group/" + g, true);
          client.send();

          client.onreadystatechange = function(){
            if (client.readyState == 4 && client.status == 200){
              var res = JSON.parse(client.response);
              thisG.list[g] = res;
              tag.update();
            }
          }
        });
      }
      
    }
    
    processLogin(e){
      e.stopPropagation();
      e.preventDefault();
      tag.auth.trigger('getToken');
      return false;
    }
    processLogout(e){
      e.stopPropagation();
      e.preventDefault();
      localStorage.removeItem("auth-token");
      tag.auth.loggedIn = "no";
      return false;
    }
    
    this.dropbox = {};
    
    drag_file(e){
      e.stopPropagation();
      e.preventDefault();
      e.dataTransfer.dropEffect = 'copy';
      return false;
    }
    
    drop_file(e){
      e.stopPropagation();
      e.preventDefault();
      var dropboxId = e.currentTarget.dataset["group"];
      var files = e.dataTransfer.files;
      f = files[0];
      
      var reader = new FileReader();
      reader.onloadend = function () {
        localStorage.setItem("file-"+dropboxId, btoa(reader.result));
        localStorage.setItem("filename-"+dropboxId, escape(f.name));
      }
      reader.readAsBinaryString(f);
      
      tag.dropbox[dropboxId] = {};
      tag.dropbox[dropboxId].name = escape(f.name);
      tag.dropbox[dropboxId].type = f.type || 'n/a';
      tag.dropbox[dropboxId].size = f.size;
      tag.dropbox[dropboxId].lastModified = f.lastModifiedDate.toLocaleDateString() || 'n/a';
      
      tag.update();
      return false;
    }
    
    upload(e){
      
      var groupId = e.currentTarget.dataset["group"];
      var client = new XMLHttpRequest();
      
      client.open("post", "../../scrapi/group/"+ groupId +"/upload", true);
      client.setRequestHeader("Content-Type", "application/json");
      client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
      var objUpload = {};
      objUpload.file = localStorage.getItem("file-" + groupId);
      fullname = localStorage.getItem("filename-" + groupId);
      var split = fullname.lastIndexOf(".")
      var filename = fullname;
      var extension = "";
      if(split != -1){
        filename = fullname.substring(0, split);
        extension = fullname.substring(split);
      }
      objUpload.name = filename;
      objUpload.extension = extension;
      objUpload.title = document.getElementById("fileTitle-" + groupId).value;
      client.send(JSON.stringify(objUpload));  /* Send to server */ 
         
      /* Check the response status */  
      client.onreadystatechange = function(){
        if (client.readyState == 4 && client.status == 200){
          delete tag.dropbox[groupId];
          tag.groups.trigger('update');
        }
      }
      
      return false;
    }
  
  </script>
  
</group-list>

