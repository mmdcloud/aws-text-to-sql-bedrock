import * as Yup from 'yup';

export const loginSchema = Yup.object().shape({
    email:Yup.string().email("Invalid email !").required("Email is required !"),
    password:Yup.string().required("Password should not be empty !").min(8,"Password should be atleast 8 characters long !")
});

export const signupSchema = Yup.object().shape({
    name:Yup.string().required("Name is required !"),
    email:Yup.string().email("Invalid email !").required("Email is required !"),
    password:Yup.string().required("Password should not be empty !").min(8,"Password should be atleast 8 characters long !"),
    repeat_password:Yup.string().required("Repeat Password should not be empty !").min(8,"Password should be atleast 8 characters long !")
});