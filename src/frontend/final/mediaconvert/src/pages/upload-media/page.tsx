import { useFormik } from "formik";

export default function UploadMedia() {
    const formik = useFormik({
        initialValues: {
            name: "",
            files: []
        },
        onSubmit: (values) => {
            console.log(values);
            //   mutation.mutate(values);
            // axiosInstanceWithBlob.put();
        }
    });
    return <div className="content-center h-screen">
        <form onSubmit={formik.handleSubmit} className="max-w-sm mx-auto items-center">
            <div className="mb-5">
                <label className="block mb-2 text-sm font-medium text-gray-900 dark:text-white">Media Name</label>
                <input type="text" id="name" name="name" onChange={formik.handleChange} value={formik.values.name} className="shadow-sm bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500 dark:shadow-sm-light" placeholder="Media Name" required />
            </div>
            <div className="mb-5">
                <label className="block mb-2 text-sm font-medium text-gray-900 dark:text-white">Select File to Upload</label>
                <input onChange={(event) => {
                    formik.setFieldValue("files", event.target.files);
                }} type="file" id="file" className="shadow-sm bg-gray-50 text-gray-900 text-sm rounded-lg focus:ring-blue-500 block w-full p-2.5 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:shadow-sm-light" required />
            </div>
            <button type="submit" className="mb-5 text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800">Submit</button>
        </form>
    </div>
}