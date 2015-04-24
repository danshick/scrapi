<group-list>

  <form class="login" if="{ auth.loggedIn == 'no' }" onsubmit={ processLogin } >
    <input type="text" id="username" placeholder="Username" data-edit="username" onkeyup="{ inputEdit }" ></input><br/>
    <input type="password" id="password" placeholder="Password" data-edit="password" onkeyup="{ inputEdit }" ></input>
    <input type="submit" value="Log In"></input>
  </form>
  
  <div if="{ auth.loggedIn == 'yes' }">
    <input type="button" id="logout" value="Logout" onclick={ processLogout }></input>
    <ul>
      <li each="{ g, gobj in groups.list }" >
        <h3>
          { g }
          <i class="fa fa-arrow-up" data-group="{ g }" data-action="up" onclick={ parent.move_group }></i>
          <i class="fa fa-arrow-down" data-group="{ g }" data-action="down" onclick={ parent.move_group }></i>
          <i class="fa fa-trash-o" data-group="{ g }" onclick={ parent.delete_group } ></i>
        </h3>
        <ul>
          <li each="{ f, fobj in gobj }" >
            { f } - <a href="/scrapi/group/{ g }/{ f }" >{ fobj.name + '.' + fobj.ext }</a> - SHA1: { fobj.sha1 }
            <i class="fa fa-arrow-up" data-group="{ g }" data-file="{ f }" data-action="up" onclick={ parent.parent.move_file }></i>
            <i class="fa fa-arrow-down" data-group="{ g }" data-file="{ f }" data-action="down" onclick={ parent.parent.move_file }></i>
            <i class="fa fa-trash-o" data-group="{ g }" data-file="{ f }" onclick={ parent.parent.delete_file } ></i>
          </li>
          <li>
            <div class="drop_zone" id="drop_zone_{ g }" data-group="{ g }" ondrop={ parent.drop_file } ondragover={ parent.drag_file }>
              <div if="{ parent.dropbox.hasOwnProperty(g) }">
                <input type="text" id="fileTitle-{ g }" data-edit="filetitle-{ g }" onkeyup="{ parent.inputEdit }" placeholder="Enter document title"></input><br/>
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
      <li>
          <input type="text" class="bigInput" data-edit="newgroup" onkeyup="{ inputEdit }" placeholder="Enter group name"></input>
          <i class="fa fa-floppy-o" onclick={ create_group }></i>
      </li>
    </ul>
  </div>
  <script>
    
    var self = this;
    
    function Auth(){
      
      var thisL = this;
      riot.observable(this);
      this.loggedIn = "unsure";

      if(!(localStorage.getItem("auth-token") === null)){
        var client = new XMLHttpRequest();
        client.open("get", "/scrapi/checkToken", true);
        client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
        client.send();
        client.onreadystatechange = function(){
          if ( client.readyState == 4 ){
            if( client.status == 200 ){
              thisL.loggedIn = "yes";
              self.update();
            }
            else{
              thisL.loggedIn = "no";
              self.update();
            }
          }
        }
      }
      else{
        thisL.loggedIn = "no";
        self.update();
      }
      
      this.on('getToken', function(){
        
        var user = self.inputText["username"];
        var pass = self.inputText["password"];
        var client = new XMLHttpRequest();
        client.open("post", "/scrapi/login", true);
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
              self.update();
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
        
        this.list = {};
        this.files = new Files();
        
        var client = new XMLHttpRequest();
        client.open("get", "/scrapi/group", true);
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
          client.open("get", "/scrapi/group/" + g, true);
          client.send();

          client.onreadystatechange = function(){
            if (client.readyState == 4 && client.status == 200){
              var res = JSON.parse(client.response);
              thisG.list[g] = res;
              self.update();
            }
          }
        });
      }
      
    }
    
    self.inputText = {};
    inputEdit(e){
      self.inputText[e.target.dataset["edit"]] = e.target.value;
    }
    
    processLogin(e){
      e.stopPropagation();
      e.preventDefault();
      self.auth.trigger('getToken');
      return false;
    }
    processLogout(e){
      e.stopPropagation();
      e.preventDefault();
      localStorage.removeItem("auth-token");
      self.auth.loggedIn = "no";
      return false;
    }
    
    delete_group(e){
      e.stopPropagation();
      e.preventDefault();

      var groupId = e.currentTarget.dataset["group"];
      
      var client = new XMLHttpRequest();
      
      client.open("delete", "/scrapi/group/"+ groupId , true);
      client.setRequestHeader("Content-Type", "application/json");
      client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
      client.send();  /* Send to server */ 
      /* Check the response status */  
      client.onreadystatechange = function(){
        if (client.readyState == 4){
          if(client.status == 200){
            self.groups.trigger('update');
          }
          else{
            humane.log("Group deletion failed. Maybe there are still files in it?", { timeout: 4000, clickToClose: true })
          }
        }
      }
      return false;
    }
    
    move_group(e){
      e.stopPropagation();
      e.preventDefault();

      var groupId = e.currentTarget.dataset["group"];
      var direction = e.currentTarget.dataset["action"];
      
      var client = new XMLHttpRequest();
      
      client.open("post", "/scrapi/group/"+ groupId , true);
      client.setRequestHeader("Content-Type", "application/json");
      client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
      client.send(JSON.stringify({"move": direction}));  /* Send to server */ 
      /* Check the response status */  
      client.onreadystatechange = function(){
        if (client.readyState == 4){
          if(client.status == 200){
            self.groups.trigger('update');
          }
          else{
            humane.log("Group move failed.", { timeout: 4000, clickToClose: true })
          }
        }
      }
      return false;
    }
    
    create_group(e){
      
      var groupId = self.inputText["newgroup"];
      var client = new XMLHttpRequest();
      
      client.open("put", "/scrapi/group/"+ groupId , true);
      client.setRequestHeader("Content-Type", "application/json");
      client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
      client.send();  /* Send to server */ 
      /* Check the response status */  
      client.onreadystatechange = function(){
        if (client.readyState == 4){
          if(client.status == 200){
            self.groups.trigger('update');
          }
          else{
            humane.log("Group creation failed.", { timeout: 4000, clickToClose: true })
          }
        }
      }
      return false;
    }
    
    delete_file(e){
      e.stopPropagation();
      e.preventDefault();

      var groupId = e.currentTarget.dataset["group"];
      var fileId = e.currentTarget.dataset["file"];
      
      var client = new XMLHttpRequest();
      
      client.open("delete", "/scrapi/group/"+ groupId +"/"+ fileId, true);
      client.setRequestHeader("Content-Type", "application/json");
      client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
      client.send();  /* Send to server */ 
      /* Check the response status */  
      client.onreadystatechange = function(){
        if (client.readyState == 4){
          if(client.status == 200){
            self.groups.trigger('update');
          }
          else{
            humane.log("File deletion failed.", { timeout: 4000, clickToClose: true })
          }
        }
      }
      return false;
    }
    
    move_file(e){
      e.stopPropagation();
      e.preventDefault();

      var groupId = e.currentTarget.dataset["group"];
      var fileId = e.currentTarget.dataset["file"];
      var direction = e.currentTarget.dataset["action"];
      
      var client = new XMLHttpRequest();
      
      client.open("post", "/scrapi/group/"+ groupId +"/"+ fileId, true);
      client.setRequestHeader("Content-Type", "application/json");
      client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
      client.send(JSON.stringify({"move": direction}));  /* Send to server */ 
      /* Check the response status */  
      client.onreadystatechange = function(){
        if (client.readyState == 4){
          if(client.status == 200){
            self.groups.trigger('update');
          }
          else{
            humane.log("File move failed.", { timeout: 4000, clickToClose: true })
          }
        }
      }
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
      
      self.dropbox[dropboxId] = {};
      self.dropbox[dropboxId].name = escape(f.name);
      self.dropbox[dropboxId].type = f.type || 'n/a';
      self.dropbox[dropboxId].size = f.size;
      self.dropbox[dropboxId].lastModified = f.lastModifiedDate.toLocaleDateString() || 'n/a';
      
      self.update();
      return false;
    }
    
    upload(e){
      
      var groupId = e.currentTarget.dataset["group"];
      var client = new XMLHttpRequest();
      
      client.open("post", "/scrapi/group/"+ groupId +"/upload", true);
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
      objUpload.title = self.inputText["filetitle-" + groupId];
      client.send(JSON.stringify(objUpload));  /* Send to server */ 
         
      /* Check the response status */  
      client.onreadystatechange = function(){
        if (client.readyState == 4 && client.status == 200){
          delete self.dropbox[groupId];
          self.groups.trigger('update');
        }
      }
      
      return false;
    }
  
  </script>
  
</group-list>

