import boto3
from botocore.exceptions import ClientError
from app.config import Config

class CognitoError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message

class CognitoService:
    def __init__(self):
        self._client = None

    @property
    def client(self):
        if not self._client:
            self._client = boto3.client("cognito-idp", region_name=Config.AWS_REGION)
        return self._client

    def sign_up(self, email: str, password: str):
        try:
            resp = self.client.sign_up(
                ClientId=Config.COGNITO_CLIENT_ID,
                Username=email,
                Password=password,
                UserAttributes=[{"Name": "email", "Value": email}],
            )
            return {"user_sub": resp["UserSub"], "user_confirmed": resp["UserConfirmed"]}
        except ClientError as e:
            raise CognitoError(e.response["Error"]["Code"], e.response["Error"]["Message"])

    def confirm_sign_up(self, email: str, code: str):
        try:
            self.client.confirm_sign_up(
                ClientId=Config.COGNITO_CLIENT_ID,
                Username=email,
                ConfirmationCode=code,
            )
        except ClientError as e:
            raise CognitoError(e.response["Error"]["Code"], e.response["Error"]["Message"])

    def resend_confirmation_code(self, email: str):
        try:
            resp = self.client.resend_confirmation_code(
                ClientId=Config.COGNITO_CLIENT_ID,
                Username=email,
            )
            delivery = resp.get("CodeDeliveryDetails", {})
            return {"delivery_medium": delivery.get("DeliveryMedium"), "destination": delivery.get("Destination")}
        except ClientError as e:
            raise CognitoError(e.response["Error"]["Code"], e.response["Error"]["Message"])

    def authenticate(self, email: str, password: str):
        try:
            resp = self.client.initiate_auth(
                ClientId=Config.COGNITO_CLIENT_ID,
                AuthFlow="USER_PASSWORD_AUTH",
                AuthParameters={"USERNAME": email, "PASSWORD": password},
            )
            auth_res = resp["AuthenticationResult"]
            return {
                "access_token": auth_res["AccessToken"],
                "id_token": auth_res["IdToken"],
                "refresh_token": auth_res.get("RefreshToken"),
                "expires_in": auth_res["ExpiresIn"],
            }
        except ClientError as e:
            raise CognitoError(e.response["Error"]["Code"], e.response["Error"]["Message"])

    def refresh_token(self, refresh_token: str):
        try:
            resp = self.client.initiate_auth(
                ClientId=Config.COGNITO_CLIENT_ID,
                AuthFlow="REFRESH_TOKEN_AUTH",
                AuthParameters={"REFRESH_TOKEN": refresh_token},
            )
            auth_res = resp["AuthenticationResult"]
            return {
                "access_token": auth_res["AccessToken"],
                "id_token": auth_res["IdToken"],
                "expires_in": auth_res["ExpiresIn"],
            }
        except ClientError as e:
            raise CognitoError(e.response["Error"]["Code"], e.response["Error"]["Message"])

    def global_sign_out(self, access_token: str):
        try:
            self.client.global_sign_out(AccessToken=access_token)
        except ClientError as e:
            raise CognitoError(e.response["Error"]["Code"], e.response["Error"]["Message"])

    def forgot_password(self, email: str):
        try:
            resp = self.client.forgot_password(
                ClientId=Config.COGNITO_CLIENT_ID,
                Username=email,
            )
            delivery = resp.get("CodeDeliveryDetails", {})
            return {"delivery_medium": delivery.get("DeliveryMedium"), "destination": delivery.get("Destination")}
        except ClientError as e:
            raise CognitoError(e.response["Error"]["Code"], e.response["Error"]["Message"])

    def confirm_forgot_password(self, email: str, code: str, new_password: str):
        try:
            self.client.confirm_forgot_password(
                ClientId=Config.COGNITO_CLIENT_ID,
                Username=email,
                ConfirmationCode=code,
                Password=new_password,
            )
        except ClientError as e:
            raise CognitoError(e.response["Error"]["Code"], e.response["Error"]["Message"])

    def change_password(self, access_token: str, old_password: str, new_password: str):
        try:
            self.client.change_password(
                PreviousPassword=old_password,
                ProposedPassword=new_password,
                AccessToken=access_token,
            )
        except ClientError as e:
            raise CognitoError(e.response["Error"]["Code"], e.response["Error"]["Message"])

cognito_service = CognitoService()