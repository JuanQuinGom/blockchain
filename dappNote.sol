pragma solidity ^0.6.0;

contract notaria{
    
    modifier checkUser(){
        require(Users[msg.sender].userAccount == msg.sender, "Usuario no autorizado");
        //require(Users[msg.sender].documentsManagedbyUser[_documentCode] == msg.sender, "Usuario no autorizado");
        _;
    }
    
    modifier checkNecessaryWitness(address _document){
        require(Documents[_document].currentWitness == Documents[_document].necessaryWitness, "No existen los testigos necesarios para firmar");
        _;
    }
    
    modifier checkContract(address _document){
        require(Documents[_document].contractActive == true, "Contrato finalizado, NO puede modificarlo");
        _;
    }
    
    struct client{
        address clientAccount;
        uint clientAmount;
        mapping (string => address) documentsManagedbyClient;//enlace de codigo del documento a direccion del cliente
    }
    
    mapping (address => client) public Clients;
    
    struct user{
        address userAccount;
        uint userBalance;
        mapping (string => address) documentsManagedbyUser; //enlace de codigo del documento a direccion del usuario
    }
    
    mapping (address => user) public Users;
    
    struct document{
        string documentCode; //el codigo a enlazar con usuario/cliente
        uint documentType;
        address documentOwner; //cliente propietario del documento, ademas de ser el encargado de la firma final
        address documentCreator;
        uint necessaryWitness;
        uint currentWitness;
        bool contractActive;
        uint price;
        uint documentBalance;
        bool isPaid;
        bool signedByUser;
        bool signedByClient;
        mapping (address => bool) documentLinkedTo;
        mapping (address => bool) documentSignedBy;
    }
    
    mapping (address => document) public Documents;


    /** funciones de creacion de estructuras **/

    /*Crea al usuario (notario)*/
    function createUser() public {
        user memory NewUser;
        NewUser.userAccount = msg.sender;
        NewUser.userBalance = 0;
        Users[msg.sender] = NewUser;
    }
    
    /*Crea al cliente, en este caso removi CURP para ser anonimo*/
    function createClient() public {
        client memory NewClient;
        NewClient.clientAccount = msg.sender;
        NewClient.clientAmount = 0;
        Clients[msg.sender] = NewClient;
    }
    
    /*Crea el documento, para ello necesitas el codigo del documento; una especie de identificador unico de este, el tipo de documento, los testigos necesarios para firmar y el coste*/
    function createDocument(string memory _documentCode, uint _documentType, uint _neccesaryWitness, uint _price) public checkUser{
        //require(Users[msg.sender].userAccount == msg.sender, "Usuario no autorizado"); // Tecnicamente el modificador hace esto...
        document memory NewDocument;
        NewDocument.documentCode = _documentCode;
        NewDocument.documentType = _documentType;
        NewDocument.documentCreator = msg.sender;
        NewDocument.necessaryWitness = _neccesaryWitness;
        NewDocument.currentWitness=0;
        NewDocument.documentBalance=0;
        NewDocument.contractActive = true;
        NewDocument.price = _price;
        NewDocument.isPaid = false;
        NewDocument.signedByClient = false;
        NewDocument.signedByUser = false;
        Documents[msg.sender] = NewDocument;
        Users[msg.sender].documentsManagedbyUser[_documentCode] = msg.sender;
        
    }
    
    /** funciones a utilizar **/
    
    /*Pagar documento, aun tengo unas dudas con la cuestion de la transferencia del Ether*/
    function payDocument(address _document, uint _amount) public payable{
        require(Documents[_document].documentOwner == msg.sender,"Usuario NO autorizado a pagar");
        require(Documents[_document].price == _amount,"Fondos insuficientes");
        //require(Documents[_document].price == msg.value,"Fondos insuficientes");
        Documents[_document].documentBalance = msg.value;
        //msg.sender.transfer(_amount); //esto no sirve
        Documents[_document].isPaid = true;
    }
    
    /* Checa el pago del documento ya sea que el usuario o el cliente deseen hacerlo */
    function checkDocumentPayment(address _document) public checkContract(_document) view returns (bool,uint) {
        require(Documents[_document].documentOwner == msg.sender || Documents[_document].documentCreator == msg.sender,"Usuario no autorizado");
        if(Documents[_document].isPaid == true){
            return (true,Documents[_document].documentBalance);
        }
        else{
            return (false,0);
        }
    }   
    
    /** Enlaza al cliente con el documento, un paso previo al pago del documento **/
    function linkClientOwner(address _document, address _clientOwner) public checkUser checkContract(_document){
        //require(Users[msg.sender].userAccount == msg.sender, "Usuario no autorizado");
        Documents[_document].documentOwner= _clientOwner;
        Clients[_clientOwner].documentsManagedbyClient[Documents[_document].documentCode]=_clientOwner;
    }
    
    
    /* Identifica si el codigo del documento ya fue enlazado al cliente */
    function checkDocumentOfClient(string memory _codeDocument) public view returns (bool){
        require(Clients[msg.sender].clientAccount == msg.sender,"Cliente no existe");
        require(Clients[msg.sender].documentsManagedbyClient[_codeDocument]!=address(0),"No hay documento enlazado");
        return true;
    }
    
    /** Checa cuantos testigos faltan por firmar el documento **/
    function checkSignedOfWitness(address _document) public checkUser checkContract(_document) view returns (uint,uint)  {
        return (Documents[_document].currentWitness, Documents[_document].necessaryWitness);
    }
    
    /** Enlaza al testigo que va a firmar el contrato con el documento, esta operacion sólo puede hacerla el usuario, NO el cliente **/
    function linkWitness(address _document, address _witness) public checkUser checkContract(_document){
        //require(Users[msg.sender].userAccount == msg.sender, "Usuario no autorizado");
        Documents[_document].documentLinkedTo[_witness] = true;
    }
    
    /** Enlaza al testigo que va a firmar el contrato con el documento, esta operacion sólo puede hacerla el usuario, NO el cliente **/
    function removeWitness(address _document, address _witnessToRemove) public checkUser checkContract(_document){
        //require(Users[msg.sender].userAccount == msg.sender, "Usuario no autorizado");
        require(Documents[_document].documentLinkedTo[_witnessToRemove] == true,"No existe el testigo");
        delete Documents[_document].documentLinkedTo[_witnessToRemove];
        Documents[_document].currentWitness--;
        
    }
    
    /** Adiciona al testigo en el documento vinculado, además de hacer un incremento para ver cuantos testigos faltan **/
    function addWitnessSignature(address _document) public checkContract(_document){
        require(Documents[_document].documentLinkedTo[msg.sender]==true,"Usuario NO autorizado, no se permite firmar");
        require(Documents[_document].documentSignedBy[msg.sender] != true,"Testigo ya firmo");
        if(Documents[_document].currentWitness < Documents[_document].necessaryWitness){
            Documents[_document].documentSignedBy[msg.sender] = true;
            Documents[_document].currentWitness++;
        }
    }
    
    /** Adiciona la firma del cliente cuando todos los testigos ya firmaron **/
    function addClientSignature(address _document) public checkNecessaryWitness(_document) checkContract(_document) {
        //require(Documents[_document].currentWitness == Documents[_document].necessaryWitness, "No existen los testigos necesarios para firmar");
        require(Documents[_document].documentOwner == msg.sender, "Se necesita al dueño del documento");
        //require(Documents[_document].contractActive == true, "Contrato finalizado, NO puede modificarlo");
        Documents[_document].signedByClient=true;
    }
    
    /**
    Finaliza el contrato dependiendo de las siguientes opciones:
    Eres el usuario del documento
    Todos los testigos han firmado
    El contrato sigue activo
    El cliente ya firmo el documento
    **/ 
    function finishContract(address payable _document) public payable checkUser checkNecessaryWitness(_document) checkContract(_document){
        require(Documents[_document].signedByClient == true,"Usuario NO ha firmado");
        Documents[_document].contractActive = false;
        msg.sender.transfer(Documents[_document].documentBalance);
    }
    
    
}