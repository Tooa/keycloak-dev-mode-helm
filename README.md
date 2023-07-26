# Keycloak Testing Helm Chart

**WARNING: DO NOT USE THIS CONFIGURATION IN PRODUCTION**

## TODO

Send scope "webclient-scope openid" in Postname or change custom claim handling
```
2023-07-23 16:14:20,468 WARN  [org.keycloak.services] (executor-thread-10) KC-SERVICES0091: Request is missing scope 'openid' so it's not treated as OIDC, but just pure OAuth2 request.
```

## Setup

```bash
# Deployment via Kind (Kubernetes in Docker) for testing purposes. Your setup may vary
$ kind create cluster --config kind-config.yaml
# Install or upgrade chart
helm upgrade --install keycloak .

$ k get services
NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
keycloak-service   ClusterIP   10.96.217.143   <none>        80/TCP      12s
kubernetes         ClusterIP   10.96.0.1       <none>        443/TCP     36m

$ k port-forward service/keycloak-service 8100:80
$ curl -X GET http://localhost:8100/

# Inspect Pod logs
$ k logs keycloak-0 --follow

$ helm uninstall keycloak
```

* User-Login page: http://localhost:8100/realms/<realm>/account/#/ (realm can be master as default or custom `myrealm`)
* Admin Console: http://localhost:8100/ (login with Keycloak management admin, see `statefulset.yaml`)

## Default Bootstrap Configuration

The default bootstrap configuration provides the following setup:

- Users `admin` and `user` (see `myrealm-users-0.json` for configuration & credentials)
  - Custom attributes `age`
  - TODO: add roles & groups
  - Note: The `admin` user is different from the Keycloak management admin user (despite both having the same name)
- A custom realm `myrealm` (see `myrealm-realm.json`)
  - Contains a custom scope `webclient-scope`. The scope maps the user's age to a custom claim `age` as type String
  - Contains a default openid-connect client `webclient`
    - Protocol: openid-connect
    - Client ID: `webclient`
    - Client secret: `BUrcJnnSWwfbMRpoF9fD9PEu1leVlwh0`
    - Redirect URIs: `https://oauth.pstmn.io/v1/callback` and `http://localhost:8000`
    - Disabled directAccessGrants
    - Auth URL: http://localhost:8100/realms/myrealm/protocol/openid-connect/auth
    - Access TOKEN URL: http://localhost:8100/realms/myrealm/protocol/openid-connect/token
    - Metadata endpoint: http://localhost:8100/realms/myrealm/.well-known/openid-configuration


> We have to use a custom realm for boostrapping, because importing the master realm is not supported because 
> as it is a very sensitive operation ([Keycloak Documentation](https://www.keycloak.org/server/importExport)).


## Update Default Bootstrap Configuration

This section describes how to update the default bootstrap configuration for your client application.
The process is as follows:

- Deploy default configuration
- Login as admin to the admin console and adapt default configuration to your use case
- Test the updated configuration with your client application
- If successful, export the realm configuration
- Update configuration in this repository with the newly exported configuration
- Redeploy the application

### Update Default Client

- Login to Keycloak via admin console: http://localhost:8100/ (for credentials)
- Select the default realm `myrealm` in the dropdown (or create a new one)
- Navigate to the clients menu & select the `webclient` client for edit
- Update values (examples)
  - client ID
  - redirect URis
  - Regenerate client secret in the client's 'Credentials' tab
- Copy the client secret from the client's 'Credentials' tab as this secret will not be exported in the following steps.
We will have to replace the secret in the exported dump manually
- Click save

### Optional: Configure Custom Claims

By default the custom user attribute `age` is added as custom claim `age` and the Keycloak default claims apply (see section "Testing the Configuration with Postman")

#### Protocol Mappers & Client Scope

Protocol mappers map items (such as an email address, for example) to a specific claim in the identity and access token. The function of a mapper should be self-explanatory from its name. See: https://www.keycloak.org/docs/latest/server_admin/#_protocol-mappers

Use Keycloak to define a shared client configuration in an entity called a **client scope**. A client scope configures protocol mappers and role scope mappings for multiple clients.

Client scopes also support the OAuth 2 scope parameter. Client applications use this parameter to request claims or roles in the access token, depending on the requirement of the application. See: https://www.keycloak.org/docs/latest/server_admin/#_client_scopes

- Add custom attributes to your users (UI -> Users -> select user -> Attributes)
  - You may also assign users to group for attribute inheritance (e.g. Admin Group and Users Group). Requires updating the field 'groups' in `myrealm-users-0.json` file.
- Navigate to 'Client Scopes; and update the `webclient-scope` (or create a new one)
  - Select type 'Default'
  - Add Mappers according to your requirements (e.g. 'User Attribute' maps a custom user attribute to a claim)
- Select your client & assign the custom scope (Clients -> <client> -> Tab Client scopes -> Add client scope)
  - Given the default bootstrap configuration, this is already the case 
- Make sure your application sends the scope parameter when authenticating via Keycloak (See section "Testing the Configuration with Postman")


### Create Users

Users are not part of the UI export dump. You may use the CLI to export users ([Keycloak Documentation](https://www.keycloak.org/server/importExport)).
The CLI exports users with encrypted passwords:

```JSON

  "realm" : "myrealm",
  "users" : [ {
    "id" : "4c973896-5761-41fc-8217-07c5d13a004b",
    "createdTimestamp" : 1505479415590,
    "username" : "admin",
    "enabled" : true,
    "totp" : false,
    "emailVerified" : true,
    "firstName" : "Admin",
    "lastName" : "Administrator",
    "email" : "admin@localhost",
    "credentials" : [ {
      "type" : "password",
      "hashedSaltedValue" : "4pf9K2jWSCcHC+CwsZP/qidN5pSmDUe6AX6wBerSGdBVKkExay8MWKx+EKmaaObZW6FVsD8vdW/ZsyUFD9gJ1Q==",
      "salt" : "1/qNkZ5kr77jOMOBPBogGw==",
      "hashIterations" : 27500,
      "counter" : 0,
      "algorithm" : "pbkdf2-sha256",
      "digits" : 0,
      "period" : 0,
      "createdDate" : 1505479429154,
      "config" : { }
    } ],
    "disableableCredentialTypes" : [ "password" ],
    "requiredActions" : [ ],
    "realmRoles" : [ "offline_access", "uma_authorization" ],
    "clientRoles" : {
      "account" : [ "view-profile", "manage-account" ]
    },
    "notBefore" : 0,
    "groups" : [  ]
  }
```

For plaintext passwords replace the "credentials" block with:

```JSON
"credentials" : [
        {
            "type": "password",
            "value": "password"
          }
      ],
```

### Export Realm

- Navigate to Configure -> Realm settings
- Click 'Action' and select 'Partial export'
- Toggle both options (group/role & client export) on and click export


### Replace Realm Configuration

- Replace the content of your local realm configuration (`myrealm-realm.json`) with the exported one
  - Replace `"secret": "**********"` in the client section with the actual client secret (obtain via keycloak UI)
- Update `myrealm-users-0.json` in case you made any changes to the users configuration such as adding users to Groups


### Re-deploy application

Redeploying the Keycloak stack updates the configuration as the Pod is ephemeral and bootstraps the configuration when the pod gets
created or is restarted. Verify configuration:

- OpenID metadata endpoint yields client configuration: http://localhost:8100/realms/<realm>/.well-known/openid-configuration
- User login via configured users possible: http://localhost:8100/realms/<realm>/account/#/
- Section" Testing the Configuration with Postman" successful


## How to create initial Bootstrap Configuration from scratch?

- Login to Keycloak via admin console: http://localhost:8100/ (for credentials)
- Create a new realm `myrealm` from the realm dropdown
- Navigate to the clients menu & click create client
- Set client ID e.g. `webclient`, name e.g. `postman-app` and click next
- Enable Client Authentication, uncheck "Direct access grants" and click next
- Enter valid redirect URLS (e.g. "http://localhost:8000", or "https://oauth.pstmn.io/v1/callback" for Postman)
- Click save
- Copy the client secret from the client's 'Credentials' tab as this secret will not be exported in the following steps
- TODO Users
- TODO Claims
- TODO Roles
- TODO Groups

## Testing the Configuration with Postman

- Install Postman
- Open Postman, select 'Authorization' and type as 'OAuth 2.0'
- Callback URL: http://localhost:8000
- AUTH URL: http://localhost:8100/realms/myrealm/protocol/openid-connect/auth
- ACCESS TOKEN URL: http://localhost:8100/realms/myrealm/protocol/openid-connect/token
- Client: webclient
- Client Secret: `BUrcJnnSWwfbMRpoF9fD9PEu1leVlwh0` (see keycloak or `myrealm-realm.json`)
- Scope: webclient-scope (Optional, client applications use this parameter to request claims or roles in the access token)

Verify result in log:

```bash
GET http://localhost:8100/realms/myrealm/protocol/openid-connect/auth?response_type=code&client_id=client&redirect_uri=http%3A%2F%2Flocalhost%3A8000
200
 
POST http://localhost:8100/realms/myrealm/login-actions/authenticate?session_code=dNlr0-1FyWuAvwvE2bZXbzhyY8syscGTut_pgtyElMI&execution=71751efc-70e5-4d3c-8490-44da64173d05&client_id=client&tab_id=RjPCB1mJSV0
302
 
POST http://localhost:8100/realms/myrealm/protocol/openid-connect/token
```

Decode token & check custom claims (e.g. `age`) via https://jwt.io/:
```JSON
// This is how the JWT token looks like in the default bootstrap configuration
{
  "exp": 1690129164,
  "iat": 1690128864,
  "auth_time": 1690128864,
  "jti": "87956647-c74e-4b27-baa5-c77841a19831",
  "iss": "http://localhost:8100/realms/myrealm",
  "aud": "account",
  "sub": "4c973896-5761-41fc-8217-07c5d13a004b",
  "typ": "Bearer",
  "azp": "webclient",
  "session_state": "f53af904-20c4-4e37-a469-2f592af6850e",
  "acr": "1",
  "allowed-origins": [
    "https://oauth.pstmn.io",
    "http://localhost:8000"
  ],
  "realm_access": {
    "roles": [
      "offline_access",
      "uma_authorization"
    ]
  },
  "resource_access": {
    "account": {
      "roles": [
        "manage-account",
        "manage-account-links",
        "view-profile"
      ]
    }
  },
  "scope": "profile email webclient-scope",
  "sid": "f53af904-20c4-4e37-a469-2f592af6850e",
  "email_verified": true,
  "name": "Admin Administrator",
  "preferred_username": "admin",
  "given_name": "Admin",
  "family_name": "Administrator",
  "email": "admin@localhost",
  "age": "10"
}
```


## Question & Answer

### Difference Role & Groups

Groups are sets of people (user) Roles are set of permission

If you use Roles, you can quickly assign lots of users to one role, and then if you need to add a group or so, just add this group to the role one time, instead of manually adding it to all the users that might or might not need to have access.

## Resources

- https://paulbares.medium.com/quick-tip-oauth2-with-keycloak-and-postman-cc7211b693a5
- https://www.baeldung.com/postman-keycloak-endpoints
- https://github.com/bitnami/charts/tree/main/bitnami/keycloak
- https://github.com/keycloak/keycloak/discussions/12594
- https://github.com/lukaszbudnik/keycloak-kubernetes/blob/main/keycloak.yaml
- https://medium.com/@shubhamdhote9717/keycloak-deployment-on-kubernetes-cluster-834bee73a567
- https://github.com/benc-uk/keycloak-helm/blob/main/keycloak/values.yaml

### Custom Claims & Scope

- https://datmt.com/backend/how-to-add-custom-claims-from-user-attributes-in-keycloak/
- https://stackoverflow.com/questions/60051209/add-claims-to-access-token-keycloak