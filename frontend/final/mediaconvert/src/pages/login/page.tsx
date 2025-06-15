import { useFormik } from "formik";
import { useNavigate } from "react-router"
import { loginSchema } from "../../utils/formSchemas";

export default function Login() {
    const navigate = useNavigate();
    const formik = useFormik({
        initialValues:{
          email:"",
          password:""
        },
        onSubmit:(values) => {
          console.log(values);
        },
        validationSchema:loginSchema
      });
    return <div className="content-center h-screen">
        <form onSubmit={formik.handleSubmit} className="max-w-sm mx-auto items-center">
            <div className="mb-5">
                <label className="block mb-2 text-sm font-medium text-gray-900 dark:text-white">Email</label>
                <input type="email" id="email" name="email" onChange={formik.handleChange} value={formik.values.email} className="shadow-sm bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500 dark:shadow-sm-light" placeholder="Email" required />
            </div>
            <div className="mb-5">
                <label className="block mb-2 text-sm font-medium text-gray-900 dark:text-white">Password</label>
                <input type="password" id="password" name="password" onChange={formik.handleChange} value={formik.values.password} className="shadow-sm bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500 dark:shadow-sm-light" required />
            </div>
            <button type="submit" className="mb-5 text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800">Login</button>
            <div className="flex items-start">
                <label className="ms-2 text-sm font-medium text-gray-900 dark:text-gray-300">Don't have an account ? <a onClick={() => {
                    navigate('/signup');
                }} className="text-blue-600 hover:underline dark:text-blue-500 cursor-pointer">Click Here For Signup</a></label>
            </div>
        </form>
    </div>
}